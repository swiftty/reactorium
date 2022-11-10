import SwiftUI
import Reactorium

private let readme = """
This screen demonstrates how to take each independent features.

It reuses the domain of the counter screen and embeds it, twice, in a larger domain.
"""

struct TwoCountersView: View {
    var body: some View {
        Form {
            Section {
                AboutView(readme: readme)
            }

            Section {
                HStack {
                    Text("Counter 1")
                    Spacer()
                    CounterView()
                        .store(initialState: .init(), reducer: Counter())
                }

                HStack {
                    Text("Counter 2")
                    Spacer()
                    CounterView()
                        .store(initialState: .init(), reducer: Counter())
                }
            }
        }
        .buttonStyle(.borderless)
        .navigationTitle("Two counter demo")
    }
}
