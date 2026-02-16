// Created by Barrett Jacobsen

import ComposableArchitecture
import Foundation
import SupacodeShared

struct RemoteControlClient {
  var start: @MainActor @Sendable (String) throws -> Void
  var stop: @MainActor @Sendable () -> Void
  var isRunning: @MainActor @Sendable () -> Bool
  var broadcastStateUpdate: @MainActor @Sendable () -> Void
  var connectedDevices: @MainActor @Sendable () -> [RemoteControlServer.ConnectedDevice]
  var disconnect: @MainActor @Sendable (UUID) -> Void
}

extension RemoteControlClient: DependencyKey {
  static let liveValue = RemoteControlClient(
    start: { _ in fatalError("RemoteControlClient.start not configured") },
    stop: { fatalError("RemoteControlClient.stop not configured") },
    isRunning: { false },
    broadcastStateUpdate: {},
    connectedDevices: { [] },
    disconnect: { _ in },
  )

  static let testValue = RemoteControlClient(
    start: { _ in },
    stop: {},
    isRunning: { false },
    broadcastStateUpdate: {},
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
