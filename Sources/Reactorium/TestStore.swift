import Foundation
import CustomDump
import Combine
import XCTestDynamicOverlay

public typealias TestStoreOf<R: Reducer> = TestStore<R.State, R.Action, R.Dependency>

@MainActor
public final class TestStore<State: Sendable, Action: Sendable, Dependency> {
    public var state: State { reducer.state }
    public var dependency: Dependency {
        get { store.dependency }
        set { store.dependency = newValue }
    }
    public var timeout: UInt64

    let reducer: TestReducer<State, Action, Dependency>
    private let store: Store<State, TestReducer<State, Action, Dependency>.TestAction, Dependency>

    private let file: StaticString
    private var line: UInt

    public init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.reducer = TestReducer(reducer, initialState: initialState)
        self.store = Store(initialState: initialState, reducer: self.reducer, dependency: dependency)
        self.timeout = 100 * NSEC_PER_MSEC
        self.file = file
        self.line = line
    }

    public convenience init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        file: StaticString = #file,
        line: UInt = #line
    ) where Dependency == Void {
        self.init(initialState: initialState, reducer: reducer, dependency: (), file: file, line: line)
    }

    deinit {
        reducer.checkCompleted(file: file, line: line)
    }
}

extension TestStore {
    @discardableResult
    public func send(
        _ action: Action,
        _ updateExpectingResult: ((inout State) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> TestStoreTask {
        if !reducer.receivedActions.isEmpty {
            var actions = ""
            customDump(reducer.receivedActions.map(\.action), to: &actions)
            XCTFail("""
            Must handle \(reducer.receivedActions.count) received \
            action\(reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

            Unhandled actions: \(actions)
            """, file: file, line: line)
        }
        var expectedState = state
        let previousState = reducer.state

        let task = store.send(.init(origin: .send(action), file: file, line: line))

        for await _ in reducer.effectDidSubscribe.stream {
            break
        }

        do {
            let currentState = state
            reducer.state = previousState
            defer { reducer.state = currentState }

            try expectedStateShouldMatch(expected: &expectedState, actual: currentState, modify: updateExpectingResult,
                                         file: file, line: line)
        } catch {
            XCTFail("Threw error: \(error)", file: file, line: line)
        }

        if "\(self.file)" == "\(file)" {
            self.line = line
        }

        await Task._yield()
        return .init(rawValue: task.task, timeout: timeout)
    }

    private func expectedStateShouldMatch(
        expected: inout State,
        actual: State,
        modify: ((inout State) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let current = expected
        if let modify {
            try modify(&expected)
        }

        if let diff = diff(expected, actual, format: .proportional) {
            let message = (
                modify != nil
                ? "A state change does not match expectation"
                : "State was not expected to change, but a change occurred"
            )
            XCTFail("""
            \(message): …

            \(diff.indent(by: 4))

            (Expected: -, Actual: +)
            """, file: file, line: line)
        } else if diff(expected, current) == nil, modify != nil {
            XCTFail("""
            Expected state to change, but no change occurred.

            The trailing closure made no observable modifications to state. If no change to state is \
            expected, omit the trailing closure.
            """, file: file, line: line)
        }
    }
}

extension TestStore {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func receive(
        _ expectedAction: Action,
        timeout duration: Duration? = nil,
        _ updateExpectingResult: ((inout State) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await receive(expectedAction, timeout: duration?.nanoseconds, updateExpectingResult,
                      file: file, line: line)
    }

    @_disfavoredOverload
    public func receive(
        _ expectedAction: Action,
        timeout nanoseconds: UInt64? = nil,
        _ updateExpectingResult: ((inout State) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {

        func _checkReceivedAction() {
            if reducer.receivedActions.isEmpty {
                XCTFail("""
                Expected to receive an action, but received none.
                """, file: file, line: line)
                return
            }

            let (receivedAction, state) = reducer.receivedActions.removeFirst()
            if let diff = diff(expectedAction, receivedAction, format: .proportional) {
                XCTFail("""
                Received unexpected action: …

                \(diff.indent(by: 4))

                (Expected: -, Received: +)
                """, file: file, line: line)
            }

            var expectedState = self.state
            do {
                try expectedStateShouldMatch(
                    expected: &expectedState,
                    actual: state,
                    modify: updateExpectingResult,
                    file: file,
                    line: line
                )
            } catch {
                XCTFail("Threw error: \(error)", file: file, line: line)
            }

            reducer.state = state
            if "\(self.file)" == "\(file)" {
                self.line = line
            }
        }

        let nanoseconds = nanoseconds ?? timeout

        if reducer.inFlightEffects.isEmpty {
            _checkReceivedAction()
            return
        }

        await Task._yield()
        let start = DispatchTime.now().uptimeNanoseconds
        while !Task.isCancelled {
            await Task._yield()

            if !reducer.receivedActions.isEmpty {
                break
            }

            if start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds {
                continue
            }

            let suggestion: String
            if reducer.inFlightEffects.isEmpty {
                suggestion = """
                There are no in-flight effects that could deliver this action. \
                Could the effect you expected to deliver this action have been cancelled?
                """
            } else {
                let message = (
                    nanoseconds != timeout
                    ? #"try increasing the duration of this assertion's "timeout""#
                    : #"configure this assertion with an explicit "timeout""#
                )
                suggestion = """
                There are effects in-flight. If the effect that delivers this action uses a \
                clock (via "sleep(for:)", etc.), make sure that you wait enough time for it to perform the effect. \
                If you are using a test clock, advance it so that the effects may complete, or consider using \
                an immediate clock to immediately perform the effect instead.

                If you are not yet using a clock, or can not use a clock, \
                \(message).
                """
            }
            XCTFail("""
            Expected to receive an action, but received none\
            \(nanoseconds > 0 ? " after \(Double(nanoseconds) / Double(NSEC_PER_SEC)) seconds" : "").

            \(suggestion)
            """, file: file, line: line)
        }

        if Task.isCancelled {
            return
        }

        _checkReceivedAction()
        await Task._yield()
    }
}

extension TestStore {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func finish(
        timeout duration: Duration? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await finish(timeout: duration?.nanoseconds, file: file, line: line)
    }

    @_disfavoredOverload
    public func finish(
        timeout nanoseconds: UInt64? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let nanoseconds = nanoseconds ?? timeout
        let start = DispatchTime.now().uptimeNanoseconds

        await Task._yield()
        while !reducer.inFlightEffects.isEmpty {
            await Task._yield()

            if start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds {
                continue
            }

            let message = (
                nanoseconds != timeout
                ? #"try increasing the duration of this assertion's "timeout""#
                : #"configure this assertion with an explicit "timeout""#
            )
            let suggestion = """
            There are effects in-flight. If the effect that delivers this action uses a \
            clock (via "sleep(for:)", etc.), make sure that you wait enough time for it to perform the effect. \
            If you are using a test clock, advance it so that the effects may complete, or consider using \
            an immediate clock to immediately perform the effect instead.

            If you are not yet using a clock, or can not use a clock, \
            \(message).
            """

            XCTFail("""
            Expected effects to finish, but there are still effects in-flight\
            \(nanoseconds > 0 ? " after \(Double(nanoseconds) / Double(NSEC_PER_SEC)) seconds" : "").

            \(suggestion)
            """, file: file, line: line)
        }
    }

    func completed() {
        if !reducer.receivedActions.isEmpty {
            var actions = ""
            customDump(reducer.receivedActions.map(\.action), to: &actions)
            XCTFail("""
            The store received \(reducer.receivedActions.count) unexpected \
            action\(reducer.receivedActions.count == 1 ? "" : "s") after this one: …

            Unhandled actions: \(actions)
            """, file: file, line: line)
        }
        for effect in reducer.inFlightEffects {
            XCTFail("""
            An effect returned for this action is still running. It must complete before the end of the test. …

            To fix, inspect any effects the reducer returns for this action and ensure that all of \
            them complete by the end of the test. There are a few reasons why an effect may not have completed:

            • If using async/await in your effect, it may need a little bit of time to properly finish.
            To fix you can simply perform "await store.finish()" at the end of your test.

            • If an effect uses a clock (via "sleep(for:)", etc.), make sure that you wait enough time \
            for it to perform the effect. If you are using a test clock, advance it so that the effects \
            may complete, or consider using an immediate clock to immediately perform the effect instead.

            • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
            then make sure those effects are torn down by marking the effect ".cancellable" and \
            returning a corresponding cancellation effect ("Effect.cancel") from another action, or, \
            if your effect is driven by a Combine subject, send it a completion.
            """, file: effect.file, line: effect.line)
        }
    }
}

// MARK: -
public struct TestStoreTask: Hashable, Sendable {
    private let rawValue: Task<Void, Never>?
    private let timeout: UInt64

    public var isCancelled: Bool {
        rawValue?.isCancelled ?? true
    }

    public init(rawValue: Task<Void, Never>?, timeout: UInt64) {
        self.rawValue = rawValue
        self.timeout = timeout
    }

    public func cancel() async {
        rawValue?.cancel()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await rawValue?.value
            }
        }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func finish(
        timeout duration: Duration? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await finish(timeout: duration?.nanoseconds, file: file, line: line)
    }

    @_disfavoredOverload
    public func finish(
        timeout nanoseconds: UInt64? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let nanoseconds = nanoseconds ?? timeout
        await Task._yield()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    await rawValue?.value
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: nanoseconds)
                    throw CancellationError()
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            let timeoutMessage = (
                nanoseconds != self.timeout
                ? #"try increasing the duration of this assertion's "timeout""#
                : #"configure this assertion with an explicit "timeout""#
            )
            let suggestion = """
            If this task delivers its action using a clock (via "sleep(for:)", etc.), \
            make sure that you wait enough time for it to perform its work. \
            If you are using a test clock, advance the scheduler so that the effects may complete, \
            or consider using an immediate clock to immediately perform the effect instead.

            If you are not yet using a clock, or cannot use a clock, \
            \(timeoutMessage).
            """

            XCTFail("""
            Expected task to finish, but it is still in-flight\
            \(nanoseconds > 0 ? " after \(Double(nanoseconds) / Double(NSEC_PER_SEC)) seconds" : "").

            \(suggestion)
            """, file: file, line: line)
        }
    }
}

// MARK: - TestReducer
final class TestReducer<State, Action: Sendable, Dependency>: Reducer {
    let base: any Reducer<State, Action, Dependency>
    let effectDidSubscribe = AsyncStream<Void>.withContinuation()
    var state: State
    var receivedActions: [(action: Action, state: State)] = []
    var inFlightEffects: Set<LongLivingEffect> = []

    init(
        _ base: some Reducer<State, Action, Dependency>,
        initialState: State
    ) {
        self.base = base
        self.state = initialState
    }

    func reduce(into state: inout State, action: TestAction, dependency: Dependency) -> Effect<TestAction> {
        let reducer = base

        let effects: Effect<Action>
        switch action.origin {
        case .send(let action):
            effects = reducer.reduce(into: &state, action: action, dependency: dependency)
            self.state = state

        case .receive(let action):
            effects = reducer.reduce(into: &state, action: action, dependency: dependency)
            receivedActions.append((action, state))
        }

        switch effects.operation {
        case .none:
            effectDidSubscribe.continuation.yield()
            return nil

        case .task:
            let effect = LongLivingEffect(file: action.file, line: action.line)
            return effects
                .map { body in
                    return { [weak self] send in
                        self?.inFlightEffects.insert(effect)
                        Task {
                            await Task._yield()
                            self?.effectDidSubscribe.continuation.yield()
                        }

                        await body(send)

                        self?.inFlightEffects.remove(effect)
                    }
                }
                .map { .init(origin: .receive($0), file: action.file, line: action.line) }
        }
    }

    struct LongLivingEffect: Hashable {
        let id = UUID()
        let file: StaticString
        let line: UInt

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    struct TestAction: Sendable{
        let origin: Origin
        let file: StaticString
        let line: UInt

        enum Origin: Sendable {
            case send(Action)
            case receive(Action)
        }
    }
}

private extension TestReducer {
    func checkCompleted(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if !receivedActions.isEmpty {
            var actions = ""
            customDump(receivedActions.map(\.action), to: &actions)
            XCTFail("""
            The store received \(receivedActions.count) unexpected \
            action\(receivedActions.count == 1 ? "" : "s") after this one: …

            Unhandled actions: \(actions)
            """, file: file, line: line)
        }
        for effect in inFlightEffects {
            XCTFail("""
            An effect returned for this action is still running. It must complete before the end of the test. …

            To fix, inspect any effects the reducer returns for this action and ensure that all of \
            them complete by the end of the test. There are a few reasons why an effect may not have completed:

            • If using async/await in your effect, it may need a little bit of time to properly finish.
            To fix you can simply perform "await store.finish()" at the end of your test.

            • If an effect uses a clock (via "sleep(for:)", etc.), make sure that you wait enough time \
            for it to perform the effect. If you are using a test clock, advance it so that the effects \
            may complete, or consider using an immediate clock to immediately perform the effect instead.

            • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
            then make sure those effects are torn down by marking the effect ".cancellable" and \
            returning a corresponding cancellation effect ("Effect.cancel") from another action, or, \
            if your effect is driven by a Combine subject, send it a completion.
            """, file: effect.file, line: effect.line)
        }
    }
}

// MARK: - helpers
private extension AsyncStream {
    static func withContinuation(
        _ elementType: Element.Type = Element.self,
        bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: Self, continuation: Continuation) {
        var continuation: Continuation!
        return (self.init(elementType, bufferingPolicy: limit) { continuation = $0 }, continuation)
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
private extension Duration {
    var nanoseconds: UInt64 {
        UInt64(components.seconds) * NSEC_PER_SEC
        + UInt64(components.attoseconds) / 1_000_000_000
    }
}

private extension String {
    func indent(by indent: Int) -> String {
        let indent = String(repeating: " ", count: indent)
        return indent + components(separatedBy: "\n").joined(separator: "\n\(indent)")
    }
}
