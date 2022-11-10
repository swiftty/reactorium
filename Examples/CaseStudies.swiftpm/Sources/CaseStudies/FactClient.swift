import SwiftUI

struct FactClient {
    var fetch: @Sendable (Int) async throws -> String
}

extension FactClient {
    static var live: Self {
        self.init(
            fetch: { number in
                try await Task.sleep(for: .seconds(1))
                let (data, _) = try await URLSession.shared
                  .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
                return String(decoding: data, as: UTF8.self)
            }
        )
    }
}

extension EnvironmentValues {
    private struct Key: EnvironmentKey {
        static var defaultValue: FactClient { FactClient(fetch: { _ in fatalError() }) }
    }
    var factClient: FactClient {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}
