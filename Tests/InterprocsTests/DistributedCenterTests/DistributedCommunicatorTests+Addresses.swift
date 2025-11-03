import XCTest
@testable import Interprocs

final class DistributedCommunicatorTests_Addresses: XCTestCase {
    // MARK: - DESTINATION ADDRESS

    func test_DestinationAddressSet_ReceivesMessageCorrectDestination() throws {
        let commA = DistributedCommunicator(id: #function, address: "A")
        let commB = DistributedCommunicator(id: #function, address: "B")
        let commC = DistributedCommunicator(id: #function, address: "C")
        let message = "Hello, B"
        let expectB = expectation(description: "When communicator A sends notification to address B which receives it.")
        let expectC = expectation(description: "When communicator A sends notification to address B and the C doesn't receives it.")
        expectC.isInverted = true
        commB.subscribe(on: #function, receive: String.self) { obj in
            XCTAssertEqual(obj, message)
            expectB.fulfill()
        }
        commC.subscribe(on: #function, receive: String.self) { obj in
            expectC.fulfill()
        }
        commA.send(message, to: "B", with: #function)
        wait(for: [expectB, expectC], timeout: 1)
    }

    func test_DestinationAddressNotSet_ReceivedByOtherDestinations() throws {
        let commA = DistributedCommunicator(id: #function, address: "A")
        let commB = DistributedCommunicator(id: #function, address: "B")
        let commC = DistributedCommunicator(id: #function, address: "C")
        let message = "Hello, all"
        let expect = expectation(description: "When communicator A sends notification without address it's received by others.")
        expect.expectedFulfillmentCount = 2
        commB.subscribe(on: #function, receive: String.self) { obj in
            XCTAssertEqual(obj, message)
            expect.fulfill()
        }
        commC.subscribe(on: #function, receive: String.self) { obj in
            XCTAssertEqual(obj, message)
            expect.fulfill()
        }
        commA.send(message, with: #function)
        wait(for: [expect], timeout: 1)
    }

    // MARK: - SOURCE ADDRESS

    func test_WhenSourceAddressSet_NotReceivedFromOthers() throws {
        let commA = DistributedCommunicator(id: #function, address: "A")
        let commB = DistributedCommunicator(id: #function, address: "B")
        let messageA = "Hello from A"
        let expectBFromC = expectation(description: "When communicator A sends notification and B waits only from C.")
        expectBFromC.isInverted = true
        commB.subscribe(on: #function, receive: String.self, from: "C") { obj in
            expectBFromC.fulfill()
        }
        commA.send(messageA, with: #function)
        wait(for: [expectBFromC], timeout: 1)
    }

    func test_WhenSourceAddressSet_ReceivesFromIt() throws {
        let commB = DistributedCommunicator(id: #function, address: "B")
        let commC = DistributedCommunicator(id: #function, address: "C")
        let messageC = "Hello from C"
        let expectBFromC = expectation(description: "When communicator C sends notification and B receives it.")
        commB.subscribe(on: #function, receive: String.self, from: "C") { obj in
            expectBFromC.fulfill()
        }
        commC.send(messageC, with: #function)
        wait(for: [expectBFromC], timeout: 1)
    }

    // MARK: - DESTINATION AND SOURCE ADDRESSES

    func test_MultipleSourcesSend_OneToExactAddresses_WaitFromOnlyOne_ReceivesFromIt() throws {
        let commA = DistributedCommunicator(id: #function, address: "A")
        let commB = DistributedCommunicator(id: #function, address: "B")
        let commC = DistributedCommunicator(id: #function, address: "C")
        let messageAToC = "Hello from A to C"
        let messageB = "Hello from B"
        let expectCFromA = expectation(description: "When communicator A sends notification to C and C subscribed on A, receives it.")
        let expectBToC = expectation(description: "When communicator B sends notification to C and C doesn't receives it.")
        expectBToC.isInverted = true
        commC.subscribe(on: #function, receive: String.self, from: "A") { obj in
            XCTAssertEqual(obj, messageAToC)
            expectCFromA.fulfill()
        }
        commC.subscribe(on: #function, receive: String.self, from: "A") { obj in
            guard obj != messageAToC else { return }
            expectBToC.fulfill()
        }
        commA.send(messageAToC, to: "C", with: #function)
        commB.send(messageB, to: "C", with: #function)
        wait(for: [expectCFromA, expectBToC], timeout: 1)
    }
}
