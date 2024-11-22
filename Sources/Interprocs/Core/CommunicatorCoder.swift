import Foundation
import Combine

public protocol CommunicatorEncoder: TopLevelEncoder where Output == Data {}

public protocol CommunicatorDecoder: TopLevelDecoder where Input == Data {}
