import SwiftUI

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension EnvironmentValues {
    private enum Key: EnvironmentKey {
        static var defaultValue: any Clock<Duration> { ContinuousClock() }
    }

    public var clock: any Clock<Duration> {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Clock {
    @inlinable
    public func sleep(for duration: Duration, tolerance: Duration? = nil) async throws {
        try await sleep(until: now.advanced(by: duration), tolerance: tolerance)
    }
}
