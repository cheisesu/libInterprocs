import Foundation
import Testing
@testable import Interprocs

struct NotificationKeyTypeTests {
    @Test("When String initialized with rawValue, rawValue equal to assigned string")
    func stringWithRawValueEqualToAssignedString() async throws {
        let stringName = "notification_name"
        let type: any NotificationKeyType = String(rawValue: stringName)
        try #require(type.rawValue == stringName)
    }

    @Test
    func notificationNameInitedWithStringLiteral() async throws {
        let stringName = "notification_name"
        var name = Notification.Name(stringLiteral: stringName)
        var type: any NotificationKeyType = name
        try #require(type.rawValue == stringName)
        name = Notification.Name(unicodeScalarLiteral: stringName)
        type = name
        try #require(type.rawValue == stringName)
        name = Notification.Name(extendedGraphemeClusterLiteral: stringName)
        type = name
        try #require(type.rawValue == stringName)
    }
}
