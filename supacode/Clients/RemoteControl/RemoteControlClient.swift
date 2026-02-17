// Created by Barrett Jacobsen

import ComposableArchitecture
import Dependencies
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
    start: unimplemented("RemoteControlClient.start"),
    stop: unimplemented("RemoteControlClient.stop"),
    isRunning: unimplemented("RemoteControlClient.isRunning", placeholder: false),
    broadcastStateUpdate: unimplemented("RemoteControlClient.broadcastStateUpdate"),
    broadcastDelta: unimplemented("RemoteControlClient.broadcastDelta"),
    connectedDevices: unimplemented("RemoteControlClient.connectedDevices", placeholder: []),
    disconnect: unimplemented("RemoteControlClient.disconnect"),
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
