import Foundation
import CustomDump
import Combine
import XCTestDynamicOverlay

public typealias TestStoreOf<R: Reducer> = TestStore<R.State, R.Action, R.Dependency>

@MainActor
public final class TestStore<State: Sendable, Action: Sendable, Dependency> {
    public var state: State {
        get { testState.state }
    }
    public var dependency: Dependency {
        get { store.dependency }
        set { store.dependency = newValue }
    }
    public var timeout: UInt64 {
        get { testState.timeout }
        set { testState.timeout = newValue }
    }

    private let store: Store<State, TestHookReducer<State, Action, Dependency>.Action, Dependency>
    private let testState: TestState<State, Action>

    public init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let testState = TestState<State, Action>(initialState: initialState, timeout: 100 * NSEC_PER_MSEC,
                                                 file: file, line: line)
        let hookReducer = TestHookReducer(reducer: reducer) { state, action, effects in
            switch action.origin {
            case .send:
                testState.state = state

            case .receive(let action):
                testState.receivedActions.append((action, state))
            }

            switch effects.operation {
            case .none:
                testState.effectDidSubscribe.continuation.yield()
                return nil

            case .task:
                let effect = TestState<State, Action>.LongLivingEffect(file: action.file, line: action.line)
                return effects.map { body in
                    return { send in
                        testState.inFlightEffects.insert(effect)
                        Task {
                            await Task._yield()
                            testState.effectDidSubscribe.continuation.yield()
                        }

                        await body(send)

                        testState.inFlightEffects.remove(effect)
                    }
                }
                .map { .init(origin: .receive($0), file: action.file, line: action.line) }
            }
        }

        self.testState = testState
        self.store = Store(initialState: initialState, reducer: hookReducer, dependency: dependency)
    }

    public convenience init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        file: StaticString = #file,
        line: UInt = #line
    ) where Dependency == Void {
        self.init(initialState: initialState, reducer: reducer, dependency: (), file: file, line: line)
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
        await testState.checkAction(action, expecting: updateExpectingResult, step: { store.send($0) },
                                    file: file, line: line)
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
        await testState.checkReceive(expectedAction, timeout: timeout, expecting: updateExpectingResult,
                                     file: file, line: line)
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
        await testState.checkRemainingInFlightEffects(timeout: timeout, file: file, line: line)
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

// MARK: - TestHookReducer
struct TestHookReducer<PState, PAction: Sendable, PDependency>: Reducer {
    struct Action: Sendable {
        let origin: Origin
        let file: StaticString
        let line: UInt

        enum Origin: Sendable {
            case send(PAction)
            case receive(PAction)

            var action: PAction {
                switch self {
                case .send(let action),
                        .receive(let action): return action
                }
            }
        }
    }
    typealias State = PState
    typealias Dependency = PDependency

    let reducer: any Reducer<PState, PAction, PDependency>
    let hook: (State, Action, Effect<PAction>) -> Effect<Action>

    init(
        reducer: some Reducer<PState, PAction, PDependency>,
        hook: @escaping (State, Action, Effect<PAction>) -> Effect<Action>
    ) {
        self.reducer = reducer
        self.hook = hook
    }

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        let effects = reducer.reduce(into: &state, action: action.origin.action, dependency: dependency)
        return hook(state, action, effects)
    }
}

// MARK: - TestState
@MainActor
final class TestState<State: Sendable, Action: Sendable> {
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

    let effectDidSubscribe = AsyncStream<Void>.withContinuation()
    var receivedActions: [(action: Action, state: State)] = []
    var inFlightEffects: Set<LongLivingEffect> = []
    var state: State
    var timeout: UInt64
    private let file: StaticString
    private var line: UInt

    init(initialState: State, timeout: UInt64, file: StaticString, line: UInt) {
        self.state = initialState
        self.timeout = timeout
        self.file = file
        self.line = line
    }

    deinit {
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

extension TestState {
    func checkAction<Dependency>(
        _ action: Action,
        expecting: ((inout State) throws -> Void)?,
        step: (TestHookReducer<State, Action, Dependency>.Action) -> Store<State, TestHookReducer<State, Action, Dependency>.Action, Dependency>.ActionTask,
        file: StaticString,
        line: UInt
    ) async -> TestStoreTask {
        if !receivedActions.isEmpty {
            var actions = ""
            customDump(receivedActions.map(\.action), to: &actions)
            XCTFail("""
            Must handle \(receivedActions.count) received \
            action\(receivedActions.count == 1 ? "" : "s") before sending an action: …

            Unhandled actions: \(actions)
            """, file: file, line: line)
        }

        var expectedState = state
        let task = step(.init(origin: .send(action), file: file, line: line))

        for await _ in effectDidSubscribe.stream {
            break
        }

        do {
            let currentState = state
            try expectedStateShouldMatch(expected: &expectedState, actual: currentState, modify: expecting,
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

extension TestState {
    func checkReceive(
        _ expectedAction: Action,
        timeout nanoseconds: UInt64?,
        expecting: ((inout State) throws -> Void)?,
        file: StaticString,
        line: UInt
    ) async {

        func _checkReceivedAction() {
            if receivedActions.isEmpty {
                XCTFail("""
                Expected to receive an action, but received none.
                """, file: file, line: line)
                return
            }

            let (receivedAction, state) = receivedActions.removeFirst()
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
                    modify: expecting,
                    file: file,
                    line: line
                )
            } catch {
                XCTFail("Threw error: \(error)", file: file, line: line)
            }

            self.state = state
            if "\(self.file)" == "\(file)" {
                self.line = line
            }
        }

        let nanoseconds = nanoseconds ?? timeout

        if inFlightEffects.isEmpty {
            _checkReceivedAction()
            return
        }

        await Task._yield()
        let start = DispatchTime.now().uptimeNanoseconds
        while !Task.isCancelled {
            await Task._yield()

            if !receivedActions.isEmpty {
                break
            }

            if start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds {
                continue
            }

            let suggestion: String
            if inFlightEffects.isEmpty {
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

extension TestState {
    func checkRemainingInFlightEffects(
        timeout nanoseconds: UInt64?,
        file: StaticString,
        line: UInt
    ) async {
        let nanoseconds = nanoseconds ?? timeout
        let start = DispatchTime.now().uptimeNanoseconds

        await Task._yield()
        while !inFlightEffects.isEmpty {
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
