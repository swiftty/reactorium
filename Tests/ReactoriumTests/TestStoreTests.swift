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
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class TestStoreTests: XCTestCase {
    func testEffectConcatenation() async {
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
}
