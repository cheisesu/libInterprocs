import Foundation

/// Policy applied to signing of notification messages.
public enum SigningPolicy: Sendable {
    /// No policy used.
    case none
    /// Default policy used.
    case `default`
}

protocol SigningMethod {
    func sign<Object: Encodable>(_ object: Object) throws -> Data
    func validate<Object: Encodable>(_ object: Object, with signature: Data?) throws
}

struct DefaultSigningMethod: SigningMethod, Sendable {
    private let encoder: JSONEncoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    func sign<Object>(_ object: Object) throws -> Data where Object : Encodable {
        let data = try encoder.encode(object)
        let signature = IdHasher(data: data).data
        return signature
    }

    func validate<Object>(_ object: Object, with signature: Data?) throws where Object : Encodable {
        let objectSignature = try sign(object)
        guard objectSignature == signature else { throw InterprocsError.invalidSignature }
    }
}

extension SigningMethod where Self == DefaultSigningMethod {
    static var `default`: Self { DefaultSigningMethod() }
}
