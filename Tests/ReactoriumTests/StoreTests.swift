import Testing
@testable import Reactorium

@MainActor
struct StoreTests {
    @Test
    func `test scoped store receives updates from parent`() async {
        struct Parent: Reducer {
            typealias State = Int
            typealias Action = Void

            func reduce(into state: inout Int, action: Void, dependency: ()) -> Effect<Void> {
                state += 1
                return nil
            }
        }
        struct Child: Reducer {
            typealias State = String
            typealias Action = Void

            func reduce(into state: inout State, action: Void, dependency: ()) -> Effect<Void> {
                return nil
            }
        }
        let parent = Store(initialState: 0, reducer: Parent(), dependency: ())
        let child = Store(binding: parent.$state.description, action: { _ in () }, reducer: Child(), dependency: ())

        #expect(child.state == "0")

        parent.send(())

        #expect(child.state == "1")
    }
}
