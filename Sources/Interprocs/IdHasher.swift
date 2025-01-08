import Foundation
import CryptoKit

struct IdHasher {
    let hash: String

    init?(value: String, encoding: String.Encoding = .utf8) {
        guard let data = value.data(using: encoding) else { return nil }
        var sha = SHA256()
        sha.update(data: data)
        let digest = sha.finalize()
        let digestData = Data(digest)
        hash = digestData.base64EncodedString()
    }
}
