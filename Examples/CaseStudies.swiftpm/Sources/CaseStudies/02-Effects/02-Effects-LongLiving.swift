import SwiftUI
import Reactorium

struct LongLivingEffects: Reducer {
    struct State {
        var screenshotCount = 0
    }

    enum Action {
        case task
        case userDidTakeScreenshotNotification
    }

    struct Dependency {
        var screenshots: () async -> AsyncStream<Void>
    }

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        switch action {
        case .task:
            return .task { send in
                for await _ in await dependency.screenshots() {
                    send(.userDidTakeScreenshotNotification)
                }
            }

        case .userDidTakeScreenshotNotification:
            state.screenshotCount += 1
            return nil
        }
    }
}

extension LongLivingEffects.Dependency {
    init(environment: EnvironmentValues) {
        screenshots = environment.screenshots
    }
}

// MARK: -
extension EnvironmentValues {
    private struct Key: EnvironmentKey {
        static var defaultValue: () async -> AsyncStream<Void> {
            return {
                .init(unfolding: { nil })
            }
        }
    }

    var screenshots: () async -> AsyncStream<Void> {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

// MARK: -
struct LongLivingEffectsView: View {
    @EnvironmentObject var store: StoreOf<LongLivingEffects>

    struct Detail: Hashable {}

    var body: some View {
        Form {
            Text("A screenshot of this screen has been taken \(store.state.screenshotCount) times.")
                .font(.headline)

            Section {
                NavigationLink(value: Detail()) {
                    Text("Navigate to another screen")
                }
            }
        }
        .navigationTitle("Long-living effects")
        .task {
            await store.send(.task).finish()
        }
        .navigationDestination(for: Detail.self) { _ in
            Text("""
            Take a screenshot of this screen a few times,
            and then go back to the preious screen to see \
            that those screenshots were not counted
            """)
            .padding(.horizontal, 64)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: -
struct LongLivingEffectsView_Preivews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LongLivingEffectsView()
                .store(initialState: .init(), reducer: LongLivingEffects(),
                       dependency: LongLivingEffects.Dependency.init)
                .environment(\.screenshots, {
                    AsyncStream(
                        Timer.publish(every: 1, on: .main, in: .default)
                            .autoconnect()
                            .map { _ in }
                            .values
                    )
                })
        }
    }
}
