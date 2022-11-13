import XCTest
import Combine
import Clocks
@testable import Reactorium

extension Effect {
    static func value(_ v: Action) -> Self {
        .task { send in
            await send(v)
        }
    }
}

@MainActor
final class TestStoreTests: XCTestCase {
    func test_effect_concatenation() async {
        guard #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) else { return }

        struct MyReducer: Reducer {
            struct State {}
            enum Action {
                case a, b1, b2, b3, c1, c2, c3, d
            }
            struct Dependency {
                var clock: any Clock<Duration>
            }

            func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
                switch action {
                case .a:
                    return .concatenate(
                        .task { _ in
                            try? await dependency.clock.sleep(for: .seconds(1))
                        },
                        .value(.b1),
                        .value(.c1)
                    )

                case .b1:
                    return .concatenate(.value(.b2), .value(.b3))

                case .c1:
                    return .concatenate(.value(.c2), .value(.c3))

                case .b2, .b3, .c2, .c3:
                    return nil

                case .d:
                    return .cancel(id: 1)
                }
            }
        }

        let clock = TestClock()
        let store = TestStore(initialState: .init(), reducer: MyReducer(), dependency: .init(clock: clock))

        await store.send(.a)

        await clock.advance(by: .seconds(1))

        await store.receive(.b1)
        await store.receive(.b2)
        await store.receive(.b3)

        await store.receive(.c1)
        await store.receive(.c2)
        await store.receive(.c3)

        await store.send(.d)
    }

    func test_async() async {
        struct MyReducer: Reducer {
            typealias State = Int
            enum Action {
                case tap, response(Int)
            }
            func reduce(into state: inout Int, action: Action, dependency: ()) -> Effect<Action> {
                switch action {
                case .tap:
                    return .task { send in
                        await send(.response(42))
                    }

                case .response(let number):
                    state = number
                    return nil
                }
            }
        }

        let store = TestStore(initialState: 0, reducer: MyReducer())

        await store.send(.tap)
        await store.receive(.response(42)) {
            $0 = 42
        }
    }

    func test_expected_state_equality() async {
        struct MyReducer: Reducer {
            struct State {
                var count = 0
                var isChanging = false
            }
            enum Action {
                case increment
                case changed(from: Int, to: Int)
            }

            func reduce(into state: inout State, action: Action, dependency: ()) -> Effect<Action> {
                switch action {
                case .increment:
                    state.isChanging = true
                    return .task { [count = state.count] send in
                        await send(.changed(from: count, to: count + 1))
                    }

                case .changed(let from, let to):
                    state.isChanging = false
                    if state.count == from {
                        state.count = to
                    }
                    return nil
                }
            }
        }

        let store = TestStore(initialState: .init(), reducer: MyReducer())

        await store.send(.increment) {
            $0.isChanging = true
        }
        await store.receive(.changed(from: 0, to: 1)) {
            $0.isChanging = false
            $0.count = 1
        }

        XCTExpectFailure("send/receive expects right state after mutation")
        await store.send(.increment) {
            $0.isChanging = false
        }
        await store.receive(.changed(from: 1, to: 2)) {
            $0.isChanging = true
            $0.count = 1100
        }
    }
}
