import Foundation

extension JSONEncoder: CommunicatorEncoder {}
extension PropertyListEncoder: CommunicatorEncoder {}

extension JSONDecoder: CommunicatorDecoder {}
extension PropertyListDecoder: CommunicatorDecoder {}
