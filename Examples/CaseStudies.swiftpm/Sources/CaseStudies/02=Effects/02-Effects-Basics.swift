import SwiftUI
import Reactorium

struct EffectsBasics: Reducer {
    struct State {
        var count = 0
        var isNumberFactRequestInFlight = false
        var numberFact: String?
    }

    enum Action {
        case decrementButtonTapped
        case decrementDelayResponse
        case incrementButtonTapped
        case numberFactButtonTapped
        case numberFactResponse(Result<String, Error>)
    }

    struct Dependency {
        var clock: any Clock<Duration>
        var factClient: FactClient
    }

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        struct DelayID {}

        switch action {
        case .decrementButtonTapped:
            state.count -= 1
            state.numberFact = nil
            return (
                state.count >= 0 ? nil : Effect.task { send in
                    try? await dependency.clock.sleep(for: .seconds(1))
                    send(.decrementDelayResponse)
                }
            )
            .cancellable(id: DelayID.self)

        case .decrementDelayResponse:
            if state.count < 0 {
                state.count += 1
            }
            return nil

        case .incrementButtonTapped:
            state.count += 1
            state.numberFact = nil
            return (
                state.count >= 0
                ? .cancel(id: DelayID.self)
                : nil
            )

        case .numberFactButtonTapped:
            state.isNumberFactRequestInFlight = true
            state.numberFact = nil
            return .task { [count = state.count] send in
                send(try await .numberFactResponse(.success(dependency.factClient.fetch(count))))
            } catch: { error, send in
                send(.numberFactResponse(.failure(error)))
            }

        case .numberFactResponse(.success(let response)):
            state.isNumberFactRequestInFlight = false
            state.numberFact = response
            return nil

        case .numberFactResponse(.failure):
            state.isNumberFactRequestInFlight = false
            return nil
        }
    }
}

extension EffectsBasics.Dependency {
    init(environment: EnvironmentValues) {
        clock = environment.clock
        factClient = environment.factClient
    }
}

// MARK: -
struct EffectsBasicsView: View {
    @EnvironmentObject var store: StoreOf<EffectsBasics>
    @Environment(\.openURL) var openURL

    var body: some View {
        Form {
            Section {
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

                Button("Number fact") {
                    store.send(.numberFactButtonTapped)
                }
                .frame(maxWidth: .infinity)

                if store.state.isNumberFactRequestInFlight {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .id(UUID())
                }

                if let numberFact = store.state.numberFact {
                    Text(numberFact)
                }
            }

            Section {
                Button("Number facts provided by numbersapi.com") {
                    openURL(URL(string: "http:// ")!)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderless)
        .navigationTitle("Effects")
    }
}

// MARK: -
struct EffectsBasicsView_Preivews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EffectsBasicsView()
                .store(initialState: .init(), reducer: EffectsBasics(),
                       dependency: EffectsBasics.Dependency.init)
                .environment(\.factClient, .init(fetch: { number in "selected \(number)." }))
        }
    }
}
