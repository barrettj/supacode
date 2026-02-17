// Created by Barrett Jacobsen

import ComposableArchitecture
import Foundation
import SupacodeShared

struct RemoteControlClient {
  var start: @MainActor @Sendable (_ pin: String, _ port: UInt16, _ name: String) throws -> Void
  var stop: @MainActor @Sendable () -> Void
  var isRunning: @MainActor @Sendable () -> Bool
  var broadcastStateUpdate: @MainActor @Sendable () -> Void
  var broadcastDelta: @MainActor @Sendable (StateDelta) -> Void
  var connectedDevices: @MainActor @Sendable () -> [RemoteControlServer.ConnectedDevice]
  var disconnect: @MainActor @Sendable (UUID) -> Void
}

extension RemoteControlClient: DependencyKey {
  static let liveValue = RemoteControlClient(
    start: { _, _, _ in
      assertionFailure("RemoteControlClient.start not configured")
    },
    stop: {
      assertionFailure("RemoteControlClient.stop not configured")
    },
    isRunning: { false },
    broadcastStateUpdate: {},
    broadcastDelta: { _ in },
    connectedDevices: { [] },
    disconnect: { _ in },
  )

  static let testValue = RemoteControlClient(
    start: { _, _, _ in },
    stop: {},
    isRunning: { false },
    broadcastStateUpdate: {},
    broadcastDelta: { _ in },
    connectedDevices: { [] },
    disconnect: { _ in },
  )
}

extension DependencyValues {
  var remoteControlClient: RemoteControlClient {
    get { self[RemoteControlClient.self] }
    set { self[RemoteControlClient.self] = newValue }
  }
}
