import SwiftUI
import Reactorium

struct RootView: View {
    enum Examples {
        struct Basics: Hashable {}
        struct OptionalBasics: Hashable {}
        struct Animations: Hashable {}
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Getting started")) {
                    NavigationLink(value: Examples.Basics()) {
                        Text("Basics")
                    }

                    NavigationLink(value: Examples.OptionalBasics()) {
                        Text("Optional state")
                    }

                    NavigationLink(value: Examples.Animations()) {
                        Text("Animations")
                    }
                }
            }
            .navigationTitle("Case Studies")
            .navigationDestination(for: Examples.Basics.self) { _ in
                CounterDemoView()
                    .store(initialState: .init(), reducer: Counter())
            }
            .navigationDestination(for: Examples.OptionalBasics.self) { _ in
                OptionalBasicsView()
                    .store(initialState: .init(), reducer: OptionalCounter())
            }
            .navigationDestination(for: Examples.Animations.self) { _ in
                AnimationsView()
                    .store(initialState: .init(), reducer: Animations(), dependency: { env in .init(clock: env.clock) })
            }
        }
    }
}
