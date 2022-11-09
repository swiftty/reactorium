import SwiftUI
import Reactorium

private let readme = """
This screen demonstrates how to show and hide views views based on the presence of some optional child state.

The parent state holds a `Counter.State?` value. When it is `nil` we will default to a plain text \
view. But when it is non-`nil` we will show a view fragment for a counter that operates on the \
non-optional counter state.

Tapping "Toggle counter state" will flip between the `nil` and non-`nil` counter states.
"""

struct OptionalCounter: Reducer {
    struct State {
        var hasCounter: Bool { optionalCounter != nil }
        var optionalCounter: Counter.State?
    }

    enum Action {
        case toggleCounterButtonTapped
        case counter(Counter.State)
    }

    func reduce(into state: inout State, action: Action, dependency: ()) -> Effect<Action> {
        switch action {
        case .toggleCounterButtonTapped:
            state.optionalCounter = state.hasCounter ? nil : .init()

        case .counter(let child):
            state.optionalCounter = child
        }
        return nil
    }
}

// MARK: -
struct OptionalBasicsView: View {
    @EnvironmentObject var store: StoreOf<OptionalCounter>

    var body: some View {
        Form {
            Section {
                AboutView(readme: readme)
            }

            Button("Toggle counter state") {
                store.send(.toggleCounterButtonTapped)
            }

            VStack(alignment: .leading) {
                if store.state.hasCounter {
                    Text("`Counter.State` is non-`nil`")
                    CounterView()
                        .scope(binding: store.$state.optionalCounter,
                               action: OptionalCounter.Action.counter,
                               reducer: Counter())
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("`Counter.State` is `nil`")
                }
            }
        }
        .navigationTitle("Optional State")
    }
}

struct TogglingCounterView: View {
    @State var toggleActive = false

    var body: some View {
        Group {
            Toggle("Toggle", isOn: $toggleActive)
            if toggleActive {
                _CounterView()
            }
        }
    }
}

struct _CounterView: View {
    @State var value = 0

    var body: some View {
        Button("Increment \(value)") {
            value += 1
        }
    }
}
