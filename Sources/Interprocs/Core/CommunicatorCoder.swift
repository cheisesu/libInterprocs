import Foundation
import Combine

/// Encoder of objects for communicators.
public protocol CommunicatorEncoder: TopLevelEncoder where Output == Data {}

/// Decoder of objects for communicators.
public protocol CommunicatorDecoder: TopLevelDecoder where Input == Data {}
