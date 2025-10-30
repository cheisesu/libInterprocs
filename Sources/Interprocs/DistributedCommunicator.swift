import Foundation
import Combine

extension DistributedCommunicator {
    struct _TransportPacket<Content: Sendable>: Sendable {
        struct _TransportMessage: Sendable {
            let tunnelId: String
            let src: String
            let content: Content
        }

        let message: _TransportMessage
        let firma: Data?
    }

    private enum _Error: Error {
        case missedTransportMessage
        case equalSourceAddress
        case identifierMismatch
    }
}

extension DistributedCommunicator._TransportPacket: Encodable where Content: Encodable {}
extension DistributedCommunicator._TransportPacket: Decodable where Content: Decodable {}
extension DistributedCommunicator._TransportPacket._TransportMessage: Encodable where Content: Encodable {}
extension DistributedCommunicator._TransportPacket._TransportMessage: Decodable where Content: Decodable {}

/// Communicator based on DistributedNotificationCenter.
///
/// - warning: Communications using this way are not secured.
@available(iOS, unavailable)
@available(tvOS, unavailable)
public class DistributedCommunicator: @unchecked Sendable {
    private let synchingQueue: DispatchQueue
    /// Hashed identiifier used for filterring notifications among all.
    private let tunnelId: String
    private let center: DistributedNotificationCenter
    private let encoder: any CommunicatorEncoder
    private let decoder: any CommunicatorDecoder
    private let signingMethod: SigningMethod?
    private var cancellables: Set<AnyCancellable> = []
    /// Hashed address of the instance. To identify nodes of communicator.
    private let address: String
    private let delegateQueue: DispatchQueue

    /// Initializes communicator.
    /// - Parameter id: Identiifier used for filterring notifications among all.
    /// - Parameter encoder: Encoder for objects to send.
    /// - Parameter decoder: Decoder for receved objects.
    /// - Parameter signingPolicy: Policy of content signing to protect modified events. Default value is ``SigningPolicy/default``.
    /// - Parameter address: Address of the instance. To identify nodes of communicator.
    /// - Parameter delegateQueue: Queue for subscribe callbacks. Default is main.
    public init(id: String, address: String, signingPolicy: SigningPolicy = .default,
                encoder: any CommunicatorEncoder = JSONEncoder(), decoder: any CommunicatorDecoder = JSONDecoder(),
                delegateQueue: DispatchQueue = .main)
    {
        tunnelId = IdHasher(value: id).stringValue
        center = .default()
        self.encoder = encoder
        self.decoder = decoder

        switch signingPolicy {
        case .none: signingMethod = nil
        case .default: signingMethod = .default
        }
        self.address = IdHasher(value: address).stringValue
        synchingQueue = .distributedSync
        self.delegateQueue = delegateQueue
    }

    /// Sends object with indicated key name.
    /// - Parameters:
    ///   - object: Instance of an object to send. It will be encoded using encoder, passed to initializer.
    ///   - key: Notification name.
    /// - Returns: True if no error happened.
    @discardableResult
    public func send<Object: Encodable & Sendable>(_ object: Object, with key: any NotificationKeyType) -> Bool {
        do {
            let transportMessage = _TransportPacket._TransportMessage(tunnelId: tunnelId, src: address, content: object)
            let signature = try signingMethod?.sign(transportMessage)
            let packet = _TransportPacket(message: transportMessage, firma: signature)
            let data = try encoder.encode(packet)
            let userInfo: [AnyHashable: Any] = [
                .Key.transportPacket: data,
            ]
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
        synchingQueue.sync {
            center
                .publisher(for: Notification.Name(key.rawValue), object: tunnelId as NSString?)
                .receive(on: delegateQueue)
                .sink { [weak self] notification in
                    guard let self else { return }
                    do {
                        let object: Object = try self.handle(notification)
                        handler(object)
                    } catch {}
                }
                .store(in: &cancellables)
        }
    }

    private func handle<Object: Codable & Sendable>(_ notification: Notification) throws -> Object {
        let packet = try parse(notification, for: Object.self)
        try validate(packet)
        return packet.message.content
    }

    private func parse<Object: Codable & Sendable>(_ notification: Notification,
                                                   for objectType: Object.Type) throws -> _TransportPacket<Object>
    {
        guard let packetData = notification.userInfo?[.Key.transportPacket] as? Data else { throw _Error.missedTransportMessage }
        let packet = try decoder.decode(_TransportPacket<Object>.self, from: packetData)
        return packet
    }

    private func validate<Object: Codable & Sendable>(_ packet: _TransportPacket<Object>) throws {
        try signingMethod?.validate(packet.message, with: packet.firma)
        guard packet.message.tunnelId == tunnelId else { throw _Error.identifierMismatch }
        guard packet.message.src != self.address else { throw _Error.equalSourceAddress }
    }
}

private extension AnyHashable {
    enum Key {
        static let transportPacket: String = "transport_packet"
    }
}
