import Foundation
import Combine

extension DistributedCommunicator {
    fileprivate struct _TransportMessage<Content: Sendable>: Sendable {
        let tunnelId: String
        let sessionId: String
        let content: Content
    }

    private enum _Error: Error {
        case missedTransportMessage
        case equalSessionId
        case identifierMismatch
    }
}

extension DistributedCommunicator._TransportMessage: Encodable where Content: Encodable {}
extension DistributedCommunicator._TransportMessage: Decodable where Content: Decodable {}

/// Communicator based on DistributedNotificationCenter.
///
/// - warning: Communications using this way are not secured.
@available(iOS, unavailable)
@available(tvOS, unavailable)
public class DistributedCommunicator {
    private let tunnelId: String
    private let center: DistributedNotificationCenter
    private let encoder: any CommunicatorEncoder
    private let decoder: any CommunicatorDecoder
    private let signingMethod: SigningMethod?
    private var cancellables: Set<AnyCancellable> = []
    private var sessionId: String { IdHasher(value: String(describing: ObjectIdentifier(self)) + tunnelId).stringValue }

    /// Initializes communicator.
    /// - Parameter id: Identiifier used for filterring notifications among all.
    /// - Parameter encoder: Encoder for objects to send.
    /// - Parameter decoder: Decoder for receved objects.
    /// - Parameter signingPolicy: Policy of content signing to protect modified events. Default value is ``SigningPolicy/default``.
    public init(id: String, signingPolicy: SigningPolicy = .default,
                encoder: any CommunicatorEncoder = JSONEncoder(), decoder: any CommunicatorDecoder = JSONDecoder())
    {
        tunnelId = IdHasher(value: id).stringValue
        center = .default()
        self.encoder = encoder
        self.decoder = decoder

        switch signingPolicy {
        case .none: signingMethod = nil
        case .default: signingMethod = .default
        }
    }

    /// Sends object with indicated key name.
    /// - Parameters:
    ///   - object: Instance of an object to send. It will be encoded using encoder, passed to initializer.
    ///   - key: Notification name.
    /// - Returns: True if no error happened.
    @discardableResult
    public func send<Object: Encodable & Sendable>(_ object: Object, with key: any NotificationKeyType) -> Bool {
        do {
            let transportMessage = _TransportMessage(tunnelId: tunnelId, sessionId: sessionId, content: object)
            let signature = try signingMethod?.sign(transportMessage)
            let data = try encoder.encode(transportMessage)
            var userInfo: [AnyHashable: Any] = [
                .Key.transportMessage: data,
            ]
            if let signature {
                userInfo[.Key.firma] = signature
            }
            center.postNotificationName(Notification.Name(key.rawValue), object: tunnelId, userInfo: userInfo, deliverImmediately: true)
            return true
        } catch {
            return false
        }
    }

    /// Subscribes on receiving notifications with passed name of concrete object type.
    ///
    /// If received object cannot be converted to provided type it will not call the handler.
    /// - Parameters:
    ///   - key: Notification name.
    ///   - type: Type of content object.
    ///   - handler: Handler of received notification.
    public func subscribe<Object: Codable & Sendable>(on key: any NotificationKeyType,
                                                      receive type: Object.Type,
                                                      handler: @escaping (_ obj: Object) -> Void)
    {
        center.publisher(for: Notification.Name(key.rawValue), object: tunnelId as NSString?)
            .sink { [weak self] notification in
                guard let self else { return }
                do {
                    let object: Object = try self.handle(notification)
                    handler(object)
                } catch {}
            }
            .store(in: &cancellables)
    }

    private func handle<Object: Codable & Sendable>(_ notification: Notification) throws -> Object {
        let (message, signature) = try parse(notification, for: Object.self)
        try validate(message, signature: signature)
        return message.content
    }

    private func parse<Object: Codable & Sendable>(_ notification: Notification,
                                                   for objectType: Object.Type) throws -> (_TransportMessage<Object>, Data?)
    {
        guard let messageData = notification.userInfo?[.Key.transportMessage] as? Data else { throw _Error.missedTransportMessage }
        let message = try decoder.decode(_TransportMessage<Object>.self, from: messageData)
        let firma = notification.userInfo?[.Key.firma] as? Data
        return (message, firma)
    }

    private func validate<Object: Codable & Sendable>(_ message: _TransportMessage<Object>, signature: Data?) throws {
        try signingMethod?.validate(message, with: signature)
        guard sessionId != message.sessionId else { throw _Error.equalSessionId }
        guard message.tunnelId == tunnelId else { throw _Error.identifierMismatch }
    }
}

private extension AnyHashable {
    enum Key {
        static let transportMessage: String = "transport_message"
        static let firma: String = "firma"
    }
}
