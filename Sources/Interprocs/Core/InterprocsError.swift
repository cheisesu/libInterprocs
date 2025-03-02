import Foundation

/// Common error of Interporcs libraray
public enum InterprocsError: Error {
    /// Message signature validating failed.
    ///
    /// It means that message probably was modified between sending and receiving or different ``SigningPolicy`` were used.
    case invalidSignature
}
