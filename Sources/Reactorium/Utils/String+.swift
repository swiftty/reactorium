import Foundation

extension String {
    func indent(by indent: Int) -> String {
        let indent = String(repeating: " ", count: indent)
        return indent + components(separatedBy: "\n").joined(separator: "\n\(indent)")
    }
}
