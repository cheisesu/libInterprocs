import XCTest
@testable import Interprocs

final class DistributedCommunicatorTests: XCTestCase {
    // When communicator (A) sends notification and doesn't receive it.
    func test_dontReceiveFromSelf() {
        let message = "hello"
        let communicator = DistributedCommunicator(id: "dont_receive_from_self")
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
        let communicatorA = DistributedCommunicator(id: "receive_by_another")
        let communicatorB = DistributedCommunicator(id: "receive_by_another")
        let expect = expectation(description: "When communicator (A) sends notification and another communicator (B) receives the notification.")
        communicatorB.subscribe(on: "test_receivesByAnother", receive: String.self) { obj in
            expect.fulfill()
        }
        communicatorA.send("hello", with: "test_receivesByAnother")
        wait(for: [expect], timeout: 1)
    }

    // When other communicator expects differnt type.
    func test_unsupportedTypeNotReceiving() {
        let communicatorA = DistributedCommunicator(id: "unsupported_type")
        let communicatorB = DistributedCommunicator(id: "unsupported_type")
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
        let communicatorA = DistributedCommunicator(id: "different_type")
        let communicatorB = DistributedCommunicator(id: "different_type_other")
        let expect = expectation(description: "When other communicator has different id it won't receive object.")
        expect.isInverted = true
        communicatorB.subscribe(on: "test_differentIdNotReceiving", receive: Int.self) { obj in
            expect.fulfill()
        }
        communicatorA.send("hello", with: "test_differentIdNotReceiving")
        wait(for: [expect], timeout: 1)
    }

    func test_unmodifiedMessageSentThroughNotificationCenter_ReceivedByCommunicator() {
        let communicator = DistributedCommunicator(id: "original_received")
        let tunnelId = "XyJYfizIN1luabkzSi+E49kT18Cp0PQWDkhf78NOieQ="
        let firma = Data(base64Encoded: "Veg6PY2wT2lZLUGJmW4D2e1AT0LsYaahEGHclzuFA5g=")!
        let originalJSON = #"{"sessionId":"\/\/YtVO9qJ2F9xi8a6rb9cwI8Im9FOpoKsYZNdQQou6s=","content":"hello","tunnelId":"XyJYfizIN1luabkzSi+E49kT18Cp0PQWDkhf78NOieQ="}"#

        let expect = expectation(description: "When unmodified data sent through usual notification center and is received.")
        communicator.subscribe(on: #function, receive: String.self) { obj in
            XCTAssertEqual(obj, "hello")
            expect.fulfill()
        }

        DistributedNotificationCenter.default().postNotificationName(#function, object: tunnelId, userInfo: [
            "firma": firma,
            "transport_message": Data(originalJSON.utf8)
        ], deliverImmediately: true)

        wait(for: [expect], timeout: 1)
    }

    func test_modifiedMessageWithOriginalValueOfDefaultSigning_NotReceived() {
        let communicator = DistributedCommunicator(id: "modified_not_received")
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

    func test_modifiedMessageWithNoSigning_Received() {
        let communicator = DistributedCommunicator(id: "modified_no_signing", signingPolicy: .none)
        let tunnelId = "XUuCpLCnkIWuqydMQQKT5RC0kpzADMF7i7sgKpYrubQ="
        let modifiedJSON = #"{"sessionId":"yMFmPY+uQRuEiybYlsZTCQkAqNW1MrzYhRRz4565\/iA=","tunnelId":"XUuCpLCnkIWuqydMQQKT5RC0kpzADMF7i7sgKpYrubQ=","content":"hello world"}"#

        let expect = expectation(description: "When modified data sent through usual notification center and is received with no signing.")
        communicator.subscribe(on: "no_sign_modified_received", receive: String.self) { obj in
            expect.fulfill()
        }
        DistributedNotificationCenter.default().postNotificationName("no_sign_modified_received", object: tunnelId, userInfo: [
            "transport_message": Data(modifiedJSON.utf8)
        ], deliverImmediately: true)

        wait(for: [expect], timeout: 1)
    }

    func test_noSigning_FirmaObjectEmpty() {
        let communicator = DistributedCommunicator(id: "no_signing_firma_empty", signingPolicy: .none)
        let expect = expectation(description: "When signing disabled in user info no signing value.")
        DistributedNotificationCenter.default().addObserver(forName: #function, object: nil, queue: .init()) { notification in
            XCTAssertNotNil(notification.userInfo)
            XCTAssertNil(notification.userInfo?["firma"])
            expect.fulfill()
        }
        communicator.send("hello", with: #function)
        wait(for: [expect], timeout: 1)
    }

    func test_differentTunnelIdWithNoSigning_NotReceived() {
        let communicator = DistributedCommunicator(id: "tunnel_id_mismatch", signingPolicy: .none)
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
        let communicator = DistributedCommunicator(id: "no_message_not_received", signingPolicy: .none)
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
        let communicator = DistributedCommunicator(id: "invalid_value", signingPolicy: .none)
        let sent = communicator.send(Double.infinity, with: "invalid_value_name")
        XCTAssertFalse(sent)
    }
}
