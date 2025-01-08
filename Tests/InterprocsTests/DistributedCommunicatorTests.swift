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
}
