// Created by Barrett Jacobsen

import ComposableArchitecture
import CryptoKit
import Foundation
import Network
import SupacodeShared
import Synchronization
import UIKit

enum RemoteStateUpdate: Equatable, Sendable {
  case connected(StateSnapshot)
  case delta(StateDelta)
  case disconnected(String?)
  case terminalContent(TerminalContent)
}

struct RemoteStateClient {
  var connect: @Sendable (NWEndpoint, String) async throws -> Void
  var stateUpdates: @Sendable () -> AsyncStream<RemoteStateUpdate>
  var send: @Sendable (RemoteCommand) async throws -> Void
  var requestTerminalContent: @Sendable (TerminalContentRequest) async throws -> Void
  var disconnect: @Sendable () -> Void
}

extension RemoteStateClient: DependencyKey {
  static var liveValue: RemoteStateClient {
    @Dependency(\.webSocketClient) var webSocketClient
    let manager = RemoteStateManager(webSocketClient: webSocketClient)
    return RemoteStateClient(
      connect: { endpoint, pin in try await manager.connect(endpoint: endpoint, pin: pin) },
      stateUpdates: { manager.stateUpdates() },
      send: { command in try await manager.send(command) },
      requestTerminalContent: { request in try await manager.requestTerminalContent(request) },
      disconnect: { manager.disconnect() },
    )
  }

  static let testValue = RemoteStateClient(
    connect: { _, _ in },
    stateUpdates: { AsyncStream { $0.finish() } },
    send: { _ in },
    requestTerminalContent: { _ in },
    disconnect: {},
  )
}

extension DependencyValues {
  var remoteStateClient: RemoteStateClient {
    get { self[RemoteStateClient.self] }
    set { self[RemoteStateClient.self] = newValue }
  }
}

// MARK: - Live Implementation

private final class RemoteStateManager: Sendable {
  private let webSocketClient: WebSocketClient

  private struct State: Sendable {
    var continuation: AsyncStream<RemoteStateUpdate>.Continuation?
  }

  private let state = Mutex(State())

  init(webSocketClient: WebSocketClient) {
    self.webSocketClient = webSocketClient
  }

  func connect(endpoint: NWEndpoint, pin: String) async throws {
    try await webSocketClient.connect(endpoint)

    let receiveStream = webSocketClient.receive()
    var iterator = receiveStream.makeAsyncIterator()

    // Wait for auth challenge
    guard let challengeMessage = await iterator.next(),
      challengeMessage.type == .authChallenge,
      let challenge = try? challengeMessage.decode(AuthChallenge.self)
    else {
      throw RemoteStateError.authFailed("No auth challenge received")
    }

    // Compute SHA256 hash of (pin + nonce)
    let hash = SHA256.hash(data: Data((pin + challenge.nonce).utf8))
      .map { String(format: "%02x", $0) }.joined()

    // Send auth request
    let deviceName = await UIDevice.current.name
    let authRequest = AuthRequest(hash: hash, deviceName: deviceName, sessionToken: nil)
    let authMessage = try RemoteMessage(type: .authRequest, payload: authRequest)
    try await webSocketClient.send(authMessage)

    // Wait for auth response
    guard let responseMessage = await iterator.next(),
      responseMessage.type == .authResponse,
      let authResponse = try? responseMessage.decode(AuthResponse.self)
    else {
      throw RemoteStateError.authFailed("No auth response received")
    }

    guard authResponse.success else {
      throw RemoteStateError.authFailed(authResponse.error ?? "Authentication failed")
    }

    // Wait for initial state snapshot
    guard let snapshotMessage = await iterator.next(),
      snapshotMessage.type == .stateSnapshot,
      let snapshot = try? snapshotMessage.decode(StateSnapshot.self)
    else {
      throw RemoteStateError.authFailed("No state snapshot received")
    }

    // Yield connected state and start message loop
    state.withLock { $0.continuation?.yield(.connected(snapshot)) }

    // Continue processing remaining messages in background
    Task { [weak self] in
      for await message in receiveStream {
        guard let self else { break }
        self.handleMessage(message)
      }
      self?.state.withLock { state in
        state.continuation?.yield(.disconnected(nil))
        state.continuation?.finish()
        state.continuation = nil
      }
    }
  }

  func stateUpdates() -> AsyncStream<RemoteStateUpdate> {
    let (stream, continuation) = AsyncStream.makeStream(of: RemoteStateUpdate.self)
    state.withLock { $0.continuation = continuation }
    return stream
  }

  func send(_ command: RemoteCommand) async throws {
    let message = try RemoteMessage(type: .command, payload: command)
    try await webSocketClient.send(message)
  }

  func requestTerminalContent(_ request: TerminalContentRequest) async throws {
    let message = try RemoteMessage(type: .terminalContentRequest, payload: request)
    try await webSocketClient.send(message)
  }

  func disconnect() {
    webSocketClient.disconnect()
    state.withLock { state in
      state.continuation?.yield(.disconnected(nil))
      state.continuation?.finish()
      state.continuation = nil
    }
  }

  private func handleMessage(_ message: RemoteMessage) {
    switch message.type {
    case .stateSnapshot:
      if let snapshot = try? message.decode(StateSnapshot.self) {
        state.withLock { $0.continuation?.yield(.connected(snapshot)) }
      }
    case .stateDelta:
      if let delta = try? message.decode(StateDelta.self) {
        state.withLock { $0.continuation?.yield(.delta(delta)) }
      }
    case .terminalContent:
      if let content = try? message.decode(TerminalContent.self) {
        state.withLock { $0.continuation?.yield(.terminalContent(content)) }
      }
    case .ping:
      let pong = RemoteMessage(type: .pong)
      Task { [weak self] in
        try? await self?.webSocketClient.send(pong)
      }
    default:
      break
    }
  }
}

enum RemoteStateError: Error, Sendable {
  case authFailed(String)
}
