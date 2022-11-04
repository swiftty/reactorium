import SwiftUI
import Reactorium

struct RootView: View {
    enum Examples {
        struct Basics: Hashable {}
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Getting started")) {
                    NavigationLink(value: Examples.Basics()) {
                        Text("Basics")
                    }
                }
            }
            .navigationTitle("Case Studies")
            .navigationDestination(for: Examples.Basics.self) { _ in
                CounterDemoView()
                    .store(initialState: .init(), reducer: Counter())
            }
        }
    }
}
