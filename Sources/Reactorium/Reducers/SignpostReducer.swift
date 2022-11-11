@preconcurrency import OSLog
import CustomDump

extension Reducer {
    /// Instruments a reducer with
    /// [signposts](https://developer.apple.com/documentation/os/logging/recording_performance_data).
    ///
    ///
    /// - Parameters:
    ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
    ///   - log: An `OSLog` to use for signposts.
    /// - Returns: A reducer that has been enhanced with instrumentation.
    @inlinable
    public func signpost(
        _ prefix: String = "",
        log: OSLog = .default
    ) -> some Reducer<State, Action, Dependency> {
        _SignpostReducer(base: self, prefix: prefix, log: log)
    }
}

extension Effect {
    @usableFromInline
    func effectSignpost(
        _ prefix: String,
        log: OSLog,
        actionOutput: String
    ) -> Self {
        let id = OSSignpostID(log: log)

        return map { body in
            return { send in
                os_signpost(
                    .begin, log: log, name: "Effect", signpostID: id,
                    "%sStarted from %s", prefix, actionOutput
                )

                await body(Send { action in
                    os_signpost(
                        .event, log: log, name: "Effect Output", signpostID: id,
                        "%sOutput from %s", prefix, actionOutput
                    )
                    send(action)
                })

                if Task.isCancelled {
                    os_signpost(
                        .end, log: log, name: "Effect", signpostID: id,
                        "%sCancelled", prefix
                    )
                } else {
                    os_signpost(
                        .end, log: log, name: "Effect", signpostID: id,
                        "%sFinished", prefix
                    )
                }
            }
        }
    }
}

// MARK: -
@usableFromInline
struct _SignpostReducer<Base: Reducer>: Reducer {
    @usableFromInline typealias State = Base.State
    @usableFromInline typealias Action = Base.Action
    @usableFromInline typealias Dependency = Base.Dependency

    @usableFromInline
    let base: Base

    @usableFromInline
    let prefix: String

    @usableFromInline
    let log: OSLog

    @usableFromInline
    init(base: Base, prefix: String, log: OSLog) {
        self.base = base
        let zeroWidthSpace = "\u{200B}"
        self.prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "
        self.log = log
    }

    @usableFromInline
    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        var actionOutput = ""
        if log.signpostsEnabled {
            customDump(action, to: &actionOutput)
            os_signpost(.begin, log: log, name: "Action", "%s%s", prefix, actionOutput)
        }

        let effects = base.reduce(into: &state, action: action, dependency: dependency)

        if log.signpostsEnabled {
            os_signpost(.end, log: log, name: "Action")
            return effects
                .effectSignpost(prefix, log: log, actionOutput: actionOutput)
        }
        return effects
    }
}
