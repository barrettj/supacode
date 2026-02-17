// Created by Barrett Jacobsen

import ComposableArchitecture
import CryptoKit
import Foundation
import Network
import OSLog
import SupacodeShared
import Synchronization
import UIKit

private let logger = Logger(subsystem: "com.supacode.remote", category: "RemoteState")

enum RemoteStateUpdate: Equatable, Sendable {
  case connected(StateSnapshot)
  case delta(StateDelta)
  case disconnected(String?)
  case terminalContent(TerminalContent)
}

struct RemoteStateClient {
  var connect: @Sendable (NWEndpoint, String, String?) async throws -> String?
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
      connect: { endpoint, pin, sessionToken in
        try await manager.connect(endpoint: endpoint, pin: pin, sessionToken: sessionToken)
      },
      stateUpdates: { manager.stateUpdates() },
      send: { command in try await manager.send(command) },
      requestTerminalContent: { request in try await manager.requestTerminalContent(request) },
      disconnect: { manager.disconnect() },
    )
  }

  static let testValue = RemoteStateClient(
    connect: { _, _, _ in nil },
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

  @discardableResult
  func connect(endpoint: NWEndpoint, pin: String, sessionToken: String? = nil) async throws -> String? {
    try await webSocketClient.connect(endpoint)

    let receiveStream = webSocketClient.receive()
    var iterator = receiveStream.makeAsyncIterator()

    // Wait for auth challenge
    guard let challengeMessage = await iterator.next(),
      challengeMessage.type == .authChallenge
    else {
      throw RemoteStateError.authFailed("No auth challenge received")
    }
    let challenge: AuthChallenge
    do {
      challenge = try challengeMessage.decode(AuthChallenge.self)
    } catch {
      logger.warning("Failed to decode auth challenge: \(error)")
      throw RemoteStateError.authFailed("Failed to decode auth challenge: \(error.localizedDescription)")
    }

    // Check protocol version compatibility
    if challenge.protocolVersion != RemoteMessage.currentVersion {
      throw RemoteStateError.protocolMismatch(
        server: challenge.protocolVersion,
        client: RemoteMessage.currentVersion,
      )
    }

    // Compute SHA256 hash of (pin + nonce)
    let hash = SHA256.hash(data: Data((pin + challenge.nonce).utf8))
      .map { String(format: "%02x", $0) }.joined()

    // Send auth request
    let deviceName = await UIDevice.current.name
    let authRequest = AuthRequest(hash: hash, deviceName: deviceName, sessionToken: sessionToken)
    let authMessage = try RemoteMessage(type: .authRequest, payload: authRequest)
    try await webSocketClient.send(authMessage)

    // Wait for auth response
    guard let responseMessage = await iterator.next(),
      responseMessage.type == .authResponse
    else {
      throw RemoteStateError.authFailed("No auth response received")
    }
    let authResponse: AuthResponse
    do {
      authResponse = try responseMessage.decode(AuthResponse.self)
    } catch {
      logger.warning("Failed to decode auth response: \(error)")
      throw RemoteStateError.authFailed("Failed to decode auth response: \(error.localizedDescription)")
    }

    guard authResponse.success else {
      throw RemoteStateError.authFailed(authResponse.error ?? "Authentication failed")
    }

    // Wait for initial state snapshot
    guard let snapshotMessage = await iterator.next(),
      snapshotMessage.type == .stateSnapshot
    else {
      throw RemoteStateError.authFailed("No state snapshot received")
    }
    let snapshot: StateSnapshot
    do {
      snapshot = try snapshotMessage.decode(StateSnapshot.self)
    } catch {
      logger.warning("Failed to decode state snapshot: \(error)")
      throw RemoteStateError.authFailed("Failed to decode state snapshot: \(error.localizedDescription)")
    }

    // Yield connected state and start message loop
    _ = state.withLock { $0.continuation?.yield(.connected(snapshot)) }

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

    return authResponse.sessionToken
  }

  func stateUpdates() -> AsyncStream<RemoteStateUpdate> {
    let (stream, continuation) = AsyncStream.makeStream(of: RemoteStateUpdate.self)
    state.withLock { state in
      state.continuation?.finish()
      state.continuation = continuation
    }
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
      do {
        let snapshot = try message.decode(StateSnapshot.self)
        _ = state.withLock { $0.continuation?.yield(.connected(snapshot)) }
      } catch {
        logger.warning("Failed to decode state snapshot: \(error)")
      }
    case .stateDelta:
      do {
        let delta = try message.decode(StateDelta.self)
        _ = state.withLock { $0.continuation?.yield(.delta(delta)) }
      } catch {
        logger.warning("Failed to decode state delta: \(error)")
      }
    case .terminalContent:
      do {
        let content = try message.decode(TerminalContent.self)
        _ = state.withLock { $0.continuation?.yield(.terminalContent(content)) }
      } catch {
        logger.warning("Failed to decode terminal content: \(error)")
      }
    case .ping:
      let pong = RemoteMessage(type: .pong)
      Task { [weak self] in
        do {
          try await self?.webSocketClient.send(pong)
        } catch {
          logger.warning("Failed to send pong: \(error)")
        }
      }
    default:
      break
    }
  }
}

enum RemoteStateError: Error, Sendable, LocalizedError {
  case authFailed(String)
  case protocolMismatch(server: Int, client: Int)

  var errorDescription: String? {
    switch self {
    case .authFailed(let message):
      return message
    case .protocolMismatch:
      return "This version of Supacode Remote is not compatible with the Mac app. Please update both apps."
    }
  }
}
