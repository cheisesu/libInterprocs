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
    private var sessionId: String { String(describing: ObjectIdentifier(self)) }

    /// Initializes communicator.
    /// - Parameter id: Identiifier used for filterring notifications.
    /// - Parameter encoder: Encoder for objects to send.
    /// - Parameter decoder: Decoder for receved objects.
    public init(id: String, encoder: any CommunicatorEncoder = JSONEncoder(), decoder: any CommunicatorDecoder = JSONDecoder()) {
        self.id = id
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
            let userInfo: [AnyHashable: Any] = [
                .Key.objectData: data,
                .Key.id: id,
                .Key.session: sessionId,
            ]
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
                let session = userInfo[.Key.session] as? String
                guard session != self.sessionId else { return }
                guard let objectData = userInfo[.Key.objectData] as? Data else { return }

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
}

private extension AnyHashable {
    enum Key {
        static let id: String = "center_id"
        static let objectData: String = "object_data"
        static let session: String = "session"
    }
}
