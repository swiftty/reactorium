import SwiftUI
import Reactorium

struct Counter: Reducer {
    struct State {
        var count = 0
    }

    enum Action {
        case decrementButtonTapped
        case incrementButtonTapped
    }

    func reduce(into state: inout State, action: Action, dependency: ()) -> Effect<Action> {
        switch action {
        case .decrementButtonTapped:
            state.count -= 1

        case .incrementButtonTapped:
            state.count += 1
        }
        return nil
    }
}

// MARK: -
struct CounterDemoView: View {
    var body: some View {
        Form {
            Section {

            }
            Section {
                CounterView()
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderless)
        .navigationTitle("Counter demo")
    }
}

struct CounterView: View {
    @EnvironmentObject var store: StoreOf<Counter>

    var body: some View {
        HStack {
            Button {
                store.send(.decrementButtonTapped)
            } label: {
                Image(systemName: "minus")
            }

            Text("\(store.state.count)")
                .monospacedDigit()

            Button {
                store.send(.incrementButtonTapped)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: -
struct CounterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CounterDemoView()
                .store(initialState: .init(count: 100), reducer: Counter())
        }
    }
}
