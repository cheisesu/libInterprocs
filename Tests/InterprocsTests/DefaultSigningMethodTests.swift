import Foundation
import Testing
@testable import Interprocs

struct DefaultSigningMethodTests {
    private enum _Error: Error {
        case unxepectedEntrance
        case unexpectedError(Error)
    }

    private struct _TestObject: Encodable, Sendable {
        let field1: String
        let field2: Int
    }
    
    @Test("When sign the same object multiple times, the result must be equal")
    func signingMultipleTimesTheSameObjectResultsEqualResults() async throws {
        let object = _TestObject(field1: "Some value 1", field2: 100500)
        let method = DefaultSigningMethod()
        let expected = "9e2/dYGjzN3UCAqfC26B8capUjoKCJQP1VYgfV+GHTc="
        for _ in 0..<100 {
            let result = try method.sign(object)
            try #require(result.base64EncodedString() == expected)
        }
    }
    
    @Test()
    func validateSignatureOfObjectSuccess() async throws {
        let object = _TestObject(field1: "Some value 1", field2: 100500)
        let method = DefaultSigningMethod()
        let expected = Data(base64Encoded: "9e2/dYGjzN3UCAqfC26B8capUjoKCJQP1VYgfV+GHTc=")!
        try method.validate(object, with: expected)
    }
    
    @Test()
    func validateSignatureOfObjectFaild() async throws {
        let object = _TestObject(field1: "Some value 1", field2: 100500)
        let method = DefaultSigningMethod()
        let expected = Data(base64Encoded: "5kdMqdfig7hDzXOXpvnou3eFGOHtsMhWiu9Kv/3wAt8=")!
        do {
            try method.validate(object, with: expected)
            throw _Error.unxepectedEntrance
        } catch InterprocsError.invalidSignature {
        } catch _Error.unxepectedEntrance {
            throw _Error.unxepectedEntrance
        } catch {
            throw _Error.unexpectedError(error)
        }
    }
}
