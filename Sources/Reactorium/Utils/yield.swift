import Foundation

extension Task<Never, Never> {
    @usableFromInline
    static func _yield(count: Int = 10) async {
        for _ in 0..<count {
            await Task<Void, Never>.detached(priority: .background) {
                await Task.yield()
            }.value
        }
    }
}
