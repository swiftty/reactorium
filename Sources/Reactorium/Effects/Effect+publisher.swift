import Foundation
@preconcurrency import Combine

extension Effect where Action: Sendable {
    @inlinable
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public static func publisher<P: Publisher & Sendable>(_ publisher: P) -> Self
    where P.Output == Action, P.Failure == Never {
        .init(operation: .task { send in
            guard !Task.isCancelled else { return }
            for await action in publisher.values {
                guard !Task.isCancelled else { break }
                send(action)
            }
        })
    }
}

extension Effect: Publisher {
    public typealias Output = Action
    public typealias Failure = Never

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        switch operation {
        case .none:
            Empty().subscribe(subscriber)

        case .task(let priority, let body):
            let subject = PassthroughSubject<Action, Never>()
            let task = Task(priority: priority) { @MainActor in
                defer { subject.send(completion: .finished) }
                await body(Send { subject.send($0) })
            }

            subject
                .handleEvents(receiveCancel: {
                    task.cancel()
                })
                .subscribe(subscriber)
        }
    }
}
