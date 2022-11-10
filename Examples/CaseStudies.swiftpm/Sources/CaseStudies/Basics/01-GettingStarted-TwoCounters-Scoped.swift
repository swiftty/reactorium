import SwiftUI
import Reactorium

private let readme = """
This screen demonstrates how to take small features and compose them into bigger ones using reducer and the `.scope` modifier.

It reuses the domain of the counter screen and embeds it, twice, in a larger domain.
"""

struct TwoCountersUsingScope: Reducer {
    struct State {
        var counter1 = Counter.State()
        var counter2 = Counter.State()
    }

    enum Action {
        case counter1(Counter.State)
        case counter2(Counter.State)
    }

    func reduce(into state: inout State, action: Action, dependency: ()) -> Effect<Action> {
        switch action {
        case .counter1(let counter1):
            state.counter1 = counter1

        case .counter2(let counter2):
            state.counter2 = counter2
        }
        return nil
    }
}

// MARK: - view
struct TwoCountersUsingScopeView: View {
    @EnvironmentObject var store: StoreOf<TwoCountersUsingScope>

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
                        .scope(binding: store.$state.counter1, action: { .counter1($0) }, reducer: Counter())
                }

                HStack {
                    Text("Counter 2")
                    Spacer()
                    CounterView()
                        .scope(binding: store.$state.counter2, action: { .counter2($0) }, reducer: Counter())
                }
            } footer: {
                Text("(using scope)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .buttonStyle(.borderless)
        .navigationTitle("Two counter demo")
    }
}

// MARK: -
struct TwoCountersUsingScope_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TwoCountersUsingScopeView()
                .store(initialState: .init(), reducer: TwoCountersUsingScope())
        }
    }
}
