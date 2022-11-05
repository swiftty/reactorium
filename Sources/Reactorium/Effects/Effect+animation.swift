import Foundation
@preconcurrency import SwiftUI

extension Effect {
    @inlinable
    public func animation(_ animation: Animation? = .default) -> Self {
        map { body in
            return { send in
                await body(Send { action in
                    withAnimation(animation) {
                        send(action)
                    }
                })
            }
        }
    }
}
