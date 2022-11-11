import SwiftUI
import Reactorium

struct Refreshable: Reducer {
    struct State {
        var count = 0
        var fact: String?
        var isLoading = false
    }

    enum Action {
        case cancelButtonTapped
        case decrementButtonTapped
        case factResponse(Result<String, Error>)
        case incrementButtonTapped
        case refresh
    }

    struct Dependency {
        var factClient: FactClient
    }

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        struct FactRequestID {}

        switch action {
        case .cancelButtonTapped:
            state.isLoading = false
            return .cancel(id: FactRequestID.self)

        case .decrementButtonTapped:
            state.count -= 1
            return nil

        case .factResponse(.success(let fact)):
            state.fact = fact
            state.isLoading = false
            return nil

        case .factResponse(.failure):
            state.isLoading = false
            return nil

        case .incrementButtonTapped:
            state.count += 1
            return nil

        case .refresh:
            state.fact = nil
            state.isLoading = true
            return .task { [count = state.count] send in
                try await send(.factResponse(.success(dependency.factClient.fetch(count))))
            } catch: { error, send in
                send(.factResponse(.failure(error)))
            }
            .animation()
            .cancellable(id: FactRequestID.self)
        }
    }
}

extension Refreshable.Dependency {
    init(environment: EnvironmentValues) {
        factClient = environment.factClient
    }
}

// MARK: -
struct RefreshableView: View {
    @EnvironmentObject var store: StoreOf<Refreshable>

    var body: some View {
        Form {
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
            .frame(maxWidth: .infinity)

            if let fact = store.state.fact {
                Text(fact)
                    .bold()
            }

            if store.state.isLoading {
                Button("cancel") {
                    store.send(.cancelButtonTapped, animation: .default)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderless)
        .refreshable {
            await store.send(.refresh).finish()
        }
    }
}
