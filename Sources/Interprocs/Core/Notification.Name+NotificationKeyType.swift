import Foundation

extension Notification.Name: @retroactive ExpressibleByStringLiteral {}
extension Notification.Name: @retroactive ExpressibleByExtendedGraphemeClusterLiteral {}
extension Notification.Name: @retroactive ExpressibleByUnicodeScalarLiteral {}

extension Notification.Name: NotificationKeyType {
    public init(stringLiteral value: StringLiteralType) {
        self = .init(value)
    }

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self = .init(value)
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self = .init(value)
    }
}
