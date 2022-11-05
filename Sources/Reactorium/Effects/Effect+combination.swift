import Foundation

// MARK: - merge
extension Effect {
    @inlinable
    public static func merge(_ effects: Self...) -> Self {
        .merge(effects)
    }

    @inlinable
    public static func merge(_ effects: [Self]) -> Self {
        effects.reduce(nil) { $0.merge(with: $1) }
    }

    @inlinable
    public func merge(with other: Self) -> Self {
        switch (operation, other.operation) {
        case (_, .none):
            return self

        case (.none, _):
            return other

        case (.task(let lhs0, let lhs1), .task(let rhs0, let rhs1)):
            return .init(operation: .task { send in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask(priority: lhs0) {
                        await lhs1(send)
                    }
                    group.addTask(priority: rhs0) {
                        await rhs1(send)
                    }
                }
            })
        }
    }
}

// MARK: - concatenate
extension Effect {
    @inlinable
    public static func concatenate(_ effects: Self...) -> Self {
        .concatenate(effects)
    }

    @inlinable
    public static func concatenate(_ effects: [Self]) -> Self {
        effects.reduce(nil) { $0.concatenate(with: $1) }
    }

    @inlinable
    public func concatenate(with other: Self) -> Self {
        switch (operation, other.operation) {
        case (_, .none):
            return self

        case (.none, _):
            return other

        case (.task(let lhs0, let lhs1), .task(let rhs0, let rhs1)):
            return .init(operation: .task { send in
                await withTaskGroup(of: Void.self) { group in
                    for (priority, operation) in [(lhs0, lhs1), (rhs0, rhs1)] {
                        let added = group.addTaskUnlessCancelled(priority: priority) {
                            await operation(send)
                        }
                        guard added else { break }
                        await group.next()
                    }
                }
            })
        }
    }
}
