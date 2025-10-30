import XCTest
@testable import Interprocs

final class DistributedCommunicatorTests: XCTestCase {
    // When communicator (A) sends notification and doesn't receive it.
    func test_dontReceiveFromSelf() {
        let message = "hello"
        let communicator = DistributedCommunicator(id: "dont_receive_from_self", address: "A")
        let expect = expectation(description: "When communicator (A) sends notification and doesn't receive it.")
        expect.isInverted = true
        communicator.subscribe(on: "test_dontReceiveFromSelf", receive: String.self) { obj in
            XCTAssertEqual(obj, message)
            expect.fulfill()
        }
        communicator.send(message, with: "test_dontReceiveFromSelf")
        wait(for: [expect], timeout: 1)
    }

    // When communicator (A) sends notification and another communicator (B) receives the notification.
    func test_receivesByAnother() {
        let communicatorA = DistributedCommunicator(id: "receive_by_another", address: "A")
        let communicatorB = DistributedCommunicator(id: "receive_by_another", address: "B")
        let expect = expectation(description: "When communicator (A) sends notification and another communicator (B) receives the notification.")
        communicatorB.subscribe(on: "test_receivesByAnother", receive: String.self) { obj in
            expect.fulfill()
        }
        communicatorA.send("hello", with: "test_receivesByAnother")
        wait(for: [expect], timeout: 1)
    }

    // When other communicator expects differnt type.
    func test_unsupportedTypeNotReceiving() {
        let communicatorA = DistributedCommunicator(id: "unsupported_type", address: "A")
        let communicatorB = DistributedCommunicator(id: "unsupported_type", address: "B")
        let expect = expectation(description: "When other communicator expects differnt type.")
        expect.isInverted = true
        communicatorB.subscribe(on: "test_unsupportedTypeNotReceiving", receive: Int.self) { obj in
            expect.fulfill()
        }
        communicatorA.send("hello", with: "test_unsupportedTypeNotReceiving")
        wait(for: [expect], timeout: 1)
    }

    // When other communicator has different id it won't receive object.
    func test_differentIdNotReceiving() {
        let communicatorA = DistributedCommunicator(id: "different_type", address: "A")
        let communicatorB = DistributedCommunicator(id: "different_type_other", address: "B")
        let expect = expectation(description: "When other communicator has different id it won't receive object.")
        expect.isInverted = true
        communicatorB.subscribe(on: "test_differentIdNotReceiving", receive: Int.self) { obj in
            expect.fulfill()
        }
        communicatorA.send("hello", with: "test_differentIdNotReceiving")
        wait(for: [expect], timeout: 1)
    }

    func test_unmodifiedMessageSentThroughNotificationCenter_ReceivedByCommunicator() throws {
        let queue = DispatchQueue(label: #function)
        let communicator = DistributedCommunicator(id: "original_received", address: "B", delegateQueue: queue)
        let address = IdHasher(value: "A").stringValue
        let tunnelId = IdHasher(value: "original_received").stringValue
        let message = "hello"
        let messageJSON = #"{"content":""# + message + #"","src":""# + address + #"","tunnelId":""# + tunnelId + #""}"#
        let _packageMessage = DistributedCommunicator._TransportPacket<String>._TransportMessage(tunnelId: tunnelId, src: address, content: message)
        let firma = try DefaultSigningMethod().sign(_packageMessage).base64EncodedString()
        let packetJSON = #"{"firma":""# + firma + #"","message":"# + messageJSON + #"}"#

        let expect = expectation(description: "When unmodified data sent through usual notification center and is received.")
        communicator.subscribe(on: #function, receive: String.self) { obj in
            XCTAssertEqual(obj, message)
            expect.fulfill()
        }

        DistributedNotificationCenter.default().postNotificationName(#function, object: tunnelId, userInfo: [
            "transport_packet": Data(packetJSON.utf8)
        ], deliverImmediately: true)

        wait(for: [expect], timeout: 1)
    }

    func test_modifiedMessageWithOriginalValueOfDefaultSigning_NotReceived() throws {
        throw XCTSkip("User info is different")

        let communicator = DistributedCommunicator(id: "modified_not_received", address: "A")
        let tunnelId = "rpdm0MWArpPtcSy301st6/9k+QZOEnHgJSDMV3rpLYo="
        let firma = Data(base64Encoded: "lx5swqgel6LqXPTWjzQ/sJHPoG05rhWvOPmDffC0W3w=")!
        let modifiedJSON = #"{"sessionId":"QtXZVwu5UuPPjXwZ4LSdKvxqRJL92ltDdDXQLVusrDA=","tunnelId":"rpdm0MWArpPtcSy301st6\/9k+QZOEnHgJSDMV3rpLYo=","content":"hello world"}"#

        let expect = expectation(description: "When modified data sent through usual notification center and is not received.")
        expect.isInverted = true
        communicator.subscribe(on: "my_notification_modif", receive: String.self) { obj in
            expect.fulfill()
        }
        DistributedNotificationCenter.default().postNotificationName("my_notification_modif", object: tunnelId, userInfo: [
            "firma": firma,
            "transport_message": Data(modifiedJSON.utf8)
        ], deliverImmediately: true)

        wait(for: [expect], timeout: 1)
    }

    func test_modifiedMessageWithNoSigning_Received() throws {
        let communicator = DistributedCommunicator(id: "no_sign_modified_received", address: "A", signingPolicy: .none)
        let address = IdHasher(value: "B").stringValue
        let tunnelId = IdHasher(value: "no_sign_modified_received").stringValue
        let modifiedJSON = #"{"firma":null,"message":{"content":"hello world","src":""# + address + #"","tunnelId":""# + tunnelId + #""}}"#
        let expect = expectation(description: "When modified data sent through usual notification center and is received with no signing.")
        communicator.subscribe(on: "no_sign_modified_received", receive: String.self) { obj in
            expect.fulfill()
        }
        DistributedNotificationCenter.default().postNotificationName("no_sign_modified_received", object: tunnelId, userInfo: [
            "transport_packet": Data(modifiedJSON.utf8)
        ], deliverImmediately: true)

        wait(for: [expect], timeout: 1)
    }

    func test_noSigning_FirmaObjectEmpty() throws {
        throw XCTSkip("User info is different already")

        let communicator = DistributedCommunicator(id: "no_signing_firma_empty", address: "A", signingPolicy: .none)
        let expect = expectation(description: "When signing disabled in user info no signing value.")
        DistributedNotificationCenter.default().addObserver(forName: #function, object: nil, queue: .init()) { notification in
            XCTAssertNotNil(notification.userInfo)
            XCTAssertNil(notification.userInfo?["firma"])
            expect.fulfill()
        }
        communicator.send("hello", with: #function)
        wait(for: [expect], timeout: 1)
    }

    func test_differentTunnelIdWithNoSigning_NotReceived() throws {
        throw XCTSkip("User info is different")

        let communicator = DistributedCommunicator(id: "tunnel_id_mismatch", address: "A", signingPolicy: .none)
        let messageJSON = #"{"sessionId":"t1lvlntZQcYt2vsPKgJ+t7p2n22zEW8e8H15pQcWcxc=","tunnelId":"phLDnCXE+cKpcsJ8SkCyEeAGHE++iUjAJsI4XXYdIQ4=","content":"hello"}"#
        let expectNotReceive = expectation(description: "When modified data sent through usual notification center and is not received.")
        expectNotReceive.isInverted = true
        communicator.subscribe(on: "my_notification_wrong_tunnel_id", receive: String.self) { obj in
            expectNotReceive.fulfill()
        }
        let tunnelId = "ohLDnCXE+cKpcsJ8SkCyEeAGHE++iUjAJsI4XXYdIQ4="
        DistributedNotificationCenter.default().postNotificationName("my_notification_wrong_tunnel_id", object: tunnelId,
                                                                     userInfo: ["transport_message": Data(messageJSON.utf8)],
                                                                     deliverImmediately: true)
        wait(for: [expectNotReceive], timeout: 1)
    }

    func test_noTransportMessage_NotReceived() {
        let communicator = DistributedCommunicator(id: "no_message_not_received", address: "A", signingPolicy: .none)
        let expectNotReceive = expectation(description: "When modified data sent through usual notification center and is not received.")
        expectNotReceive.isInverted = true
        communicator.subscribe(on: "my_notification_without_message", receive: String.self) { obj in
            expectNotReceive.fulfill()
        }
        let tunnelId = "5PMX+6xsWdhzug9p1x6PSTYl+xnc0+G/XOMAJZ3reOs="
        DistributedNotificationCenter.default().postNotificationName("my_notification_without_message", object: tunnelId,
                                                                     userInfo: [:], deliverImmediately: true)
        wait(for: [expectNotReceive], timeout: 1)
    }

    func test_invalidValue_NotSent() {
        let communicator = DistributedCommunicator(id: "invalid_value", address: "A", signingPolicy: .none)
        let sent = communicator.send(Double.infinity, with: "invalid_value_name")
        XCTAssertFalse(sent)
    }
}
