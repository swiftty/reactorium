[![test](https://github.com/swiftty/reactorium/actions/workflows/test.yml/badge.svg)](https://github.com/swiftty/reactorium/actions/workflows/test.yml)

# REACTORIUM

Highly inspired by [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture).

<br />
<br />

## # CONCEPT

A Lightwieght TCA for SwiftUI friendly.

<br />

## # INSTALLATION

**Under Development**

```swift
dependencies: [
    .package(url: "https://github.com/swiftty/reactorium", from: "0.0.1")
]
```

<br />

## # USAGE

- define Reducer

```swift
import SwiftUI
import Reactorium

struct Counter: Reducer {
    struct State {
        var count = 0
    }

    enum Action {
        case incr
        case decr
    }

    func reduce(into state: inout State, action: Action, dependency: ()) -> Effect<Action> {
        switch action {
        case .incr:
            state.count += 1
            return nil

        case .decr:
            state.count -= 1
            return nil
        }
    }
}

struct CounterView: View {
    @EnvironmentObject var store: StoreOf<Counter>

    var body: some View {
        VStack {
            Text("\(store.state.count)")

            HStack {
                Button { store.send(.decr) } label: {
                    Image(systemName: "minus")
                        .padding()
                }

                Button { store.send(.incr) } label: {
                    Image(systemName: "plus")
                        .padding()
                }
            }
        }
    }
}
```

<br />

- inject using `View.store` modifier

```swift
import SwiftUI
import Reactorium

struct MyApp: App {
    var body: some Scene {
        WindowScene {
            CounterView()
                .store(initialState: .init(), reducer: Counter())
        }
    }
}
```

<br />