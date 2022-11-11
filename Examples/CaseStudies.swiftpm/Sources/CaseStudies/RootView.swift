import SwiftUI
import Reactorium

struct RootView: View {
    enum Examples {
        struct Basics: Hashable {}
        struct TwoCountersUsingScope: Hashable {}
        struct TwoCounters: Hashable {}
        struct OptionalBasics: Hashable {}
        struct Animations: Hashable {}

        struct EffectsBasics: Hashable {}
        struct LongLivingEffects: Hashable {}
        struct Refreshable: Hashable {}
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Getting started")) {
                    NavigationLink(value: Examples.Basics()) {
                        Text("Basics")
                    }

                    NavigationLink(value: Examples.TwoCountersUsingScope()) {
                        Text("Scoped state")
                    }

                    NavigationLink(value: Examples.TwoCounters()) {
                        Text("Separated state")
                    }

                    NavigationLink(value: Examples.OptionalBasics()) {
                        Text("Optional scoped state")
                    }

                    NavigationLink(value: Examples.Animations()) {
                        Text("Animations")
                    }
                }

                Section(header: Text("Effects")) {
                    NavigationLink(value: Examples.EffectsBasics()) {
                        Text("Basics")
                    }

                    NavigationLink(value: Examples.LongLivingEffects()) {
                        Text("Long-living effects")
                    }

                    NavigationLink(value: Examples.Refreshable()) {
                        Text("Refreshable")
                    }
                }
            }
            .navigationTitle("Case Studies")
            .navigationDestination(for: Examples.Basics.self) { _ in
                CounterDemoView()
                    .store(initialState: .init(), reducer: Counter())
            }
            .navigationDestination(for: Examples.TwoCountersUsingScope.self) { _ in
                TwoCountersUsingScopeView()
                    .store(initialState: .init(), reducer: TwoCountersUsingScope())
            }
            .navigationDestination(for: Examples.TwoCounters.self) { _ in
                TwoCountersView()
            }
            .navigationDestination(for: Examples.OptionalBasics.self) { _ in
                OptionalBasicsView()
                    .store(initialState: .init(), reducer: OptionalCounter())
            }
            .navigationDestination(for: Examples.Animations.self) { _ in
                AnimationsView()
                    .store(initialState: .init(), reducer: Animations(), dependency: { env in .init(clock: env.clock) })
            }
            .navigationDestination(for: Examples.EffectsBasics.self) { _ in
                EffectsBasicsView()
                    .store(initialState: .init(), reducer: EffectsBasics(),
                           dependency: EffectsBasics.Dependency.init)
                    .environment(\.factClient, .live)
            }
            .navigationDestination(for: Examples.LongLivingEffects.self) { _ in
                LongLivingEffectsView()
                    .store(initialState: .init(), reducer: LongLivingEffects(),
                           dependency: LongLivingEffects.Dependency.init)
                    .environment(\.screenshots, {
                        AsyncStream(NotificationCenter
                            .default
                            .notifications(named: UIApplication.userDidTakeScreenshotNotification)
                            .map { _ in }
                        )
                    })
            }
            .navigationDestination(for: Examples.Refreshable.self) { _ in
                RefreshableView()
                    .store(initialState: .init(), reducer: Refreshable(),
                           dependency: Refreshable.Dependency.init)
                    .environment(\.factClient, .live)
            }
        }
    }
}

// MARK: -
extension AsyncStream {
    public init<Seq: AsyncSequence>(
        _ seq: Seq,
        bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
    ) where Seq.Element == Element {
        self.init { continuation in
            let task = Task {
                do {
                    for try await element in seq {
                        continuation.yield(element)
                    }
                } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
