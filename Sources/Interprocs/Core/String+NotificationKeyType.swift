import Foundation

extension String: @retroactive RawRepresentable {}
extension String: NotificationKeyType {
    public var rawValue: String { self }

    public init(rawValue: String) {
        self = rawValue
    }
}
