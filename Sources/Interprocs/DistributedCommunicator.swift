import Foundation
import Combine

/// Communicator based on DistributedNotificationCenter.
///
/// - warning: Communications using this way are not secured.
@available(iOS, unavailable)
public class DistributedCommunicator {
    private let id: String
    private let center: DistributedNotificationCenter
    private let encoder: any CommunicatorEncoder
    private let decoder: any CommunicatorDecoder
    private var cancellables: Set<AnyCancellable> = []

    private var notificationObject: String? { id }
    private var sessionId: String {
        let id = String(describing: ObjectIdentifier(self)) + self.id
        let hash = IdHasher(value: id)?.hash ?? String(describing: Unmanaged.passUnretained(self).toOpaque())
        return hash
    }

    /// Initializes communicator.
    /// - Parameter id: Identiifier used for filterring notifications.
    /// - Parameter encoder: Encoder for objects to send.
    /// - Parameter decoder: Decoder for receved objects.
    public init(id: String, encoder: any CommunicatorEncoder = JSONEncoder(), decoder: any CommunicatorDecoder = JSONDecoder()) {
        self.id = IdHasher(value: id)?.hash ?? id
        center = .default()
        self.encoder = encoder
        self.decoder = decoder
    }

    /// Sends object with indicated key name.
    /// - Parameters:
    ///   - object: Instance of an object to send. It will be encoded using passed encoder to initializer.
    ///   - key: Notification name.
    /// - Returns: True if no error happened.
    @discardableResult
    public func send<Object: Encodable>(_ object: Object, with key: any NotificationKeyType) -> Bool {
        do {
            let data = try encoder.encode(object)
            let name = notificationName(for: key)
            var userInfo: [AnyHashable: Any] = [
                .Key.objectData: data.base64EncodedString(),
                .Key.id: id,
                .Key.session: sessionId,
            ]
            guard let signature = signature(of: userInfo) else { return false }
            userInfo[.Key.firma] = signature
            center.postNotificationName(name, object: notificationObject, userInfo: userInfo, deliverImmediately: true)
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
    public func subscribe<Object: Decodable>(on key: any NotificationKeyType,
                                             receive type: Object.Type,
                                             handler: @escaping (_ obj: Object) -> Void)
    {
        let name = notificationName(for: key)
        center.publisher(for: name, object: notificationObject as NSString?)
            .sink { [weak self] notification in
                guard let self else { return }
                let userInfo = notification.userInfo ?? [:]
                guard let id = userInfo[.Key.id] as? String, id == self.id else { return }
                guard let session = userInfo[.Key.session] as? String else { return }
                guard session != self.sessionId else { return }
                guard let objectBase64 = userInfo[.Key.objectData] as? String else { return }
                guard let objectData = Data(base64Encoded: objectBase64) else { return }
                guard let inSignature = userInfo[.Key.firma] as? String else { return }
                guard let signature = signature(ofId: id, sessionId: session, objectBase64: objectBase64) else { return }
                guard inSignature == signature else { return }

                do {
                    let obj = try decoder.decode(Object.self, from: objectData)
                    handler(obj)
                } catch {
                }
            }
            .store(in: &cancellables)
    }

    private func notificationName(for key: any NotificationKeyType) -> Notification.Name {
        Notification.Name("\(id).\(key.rawValue)")
    }

    private func decode(userInfo: [AnyHashable: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo, options: [.sortedKeys, .prettyPrinted]) else { return nil }
        let result = String(data: data, encoding: .utf8)
        return result
    }

    private func signature(of userInfo: [AnyHashable: Any]) -> String? {
        guard let string = decode(userInfo: userInfo) else { return nil }
        return IdHasher(value: string)?.hash
    }

    private func signature(ofId id: String, sessionId: String, objectBase64: String) -> String? {
        let userInfo: [AnyHashable: Any] = [
            .Key.id: id,
            .Key.objectData: objectBase64,
            .Key.session: sessionId,
        ]
        return signature(of: userInfo)
    }
}

private extension AnyHashable {
    enum Key {
        static let id: String = "center_id"
        static let objectData: String = "object_data"
        static let session: String = "session"
        static let firma: String = "firma"
    }
}
