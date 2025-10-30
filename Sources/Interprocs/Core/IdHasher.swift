import Foundation
import CryptoKit

/// Entity that describes identifier of communications.
struct IdHasher {
    let data: Data
    let stringValue: String

    init(value: String) {
        self.init(data: Data(value.utf8))
    }

    init(data: Data) {
        var sha = SHA256()
        sha.update(data: data)
        let hashData = Data(sha.finalize())
        self.data = Data(hashData)
        stringValue = self.data.base64EncodedString()
    }
}
