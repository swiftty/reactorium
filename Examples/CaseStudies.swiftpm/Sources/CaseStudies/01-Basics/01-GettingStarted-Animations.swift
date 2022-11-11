import SwiftUI
import Reactorium

struct Animations: Reducer {
    struct State {
        var circleCenter: CGPoint?
        var circleColor = Color.black
        var isCircleScaled = false
    }

    enum Action {
        case circleScaleToggleChanged(Bool)
        case rainbowButtonTapped
        case resetButtonTapped
        case setColor(Color)
        case tapped(CGPoint)
    }

    struct Dependency {
        var clock: any Clock<Duration>
    }

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        struct CancelID {}

        switch action {
        case .circleScaleToggleChanged(let isScaled):
            state.isCircleScaled = isScaled
            return nil

        case .rainbowButtonTapped:
            return .task { send in
                for color in [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .black] {
                    await send(.setColor(color), animation: .linear)
                    try? await dependency.clock.sleep(for: .seconds(1))
                }
            }
            .cancellable(id: CancelID.self)

        case .resetButtonTapped:
            state = .init()
            return .cancel(id: CancelID.self)

        case .setColor(let color):
            state.circleColor = color
            return nil

        case .tapped(let center):
            state.circleCenter = center
            return nil
        }
    }
}

// MARK: -
struct AnimationsView: View {
    @EnvironmentObject var store: StoreOf<Animations>

    var body: some View {
        VStack(alignment: .leading) {
            Text("tap screen!")
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            store.send(
                                .tapped(gesture.location),
                                animation: .interactiveSpring(response: 0.25, dampingFraction: 0.1)
                            )
                        }
                )
                .overlay {
                    GeometryReader { proxy in
                        Circle()
                            .fill(store.state.circleColor)
                            .colorInvert()
                            .blendMode(.difference)
                            .frame(width: 50, height: 50)
                            .scaleEffect(store.state.isCircleScaled ? 2 : 1)
                            .position(
                                x: store.state.circleCenter?.x ?? proxy.size.width / 2,
                                y: store.state.circleCenter?.y ?? proxy.size.height / 2
                            )
                            .offset(y: store.state.circleCenter == nil ? 0 : -44)
                    }
                    .allowsHitTesting(false)
                }

            Toggle(
                "Big mode",
                isOn: store.$state.isCircleScaled(action: { .circleScaleToggleChanged($0) })
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
            )
            .padding()

            Button("Rainbow") {
                store.send(.rainbowButtonTapped, animation: .linear)
            }
            .padding([.horizontal, .bottom])

            Button("Reset") {
                store.send(.resetButtonTapped, animation: .default)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: -
struct AnimationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AnimationsView()
                .store(
                    initialState: .init(),
                    reducer: Animations(),
                    dependency: { env in .init(clock: env.clock) }
                )
        }
    }
}
