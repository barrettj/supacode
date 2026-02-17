// Created by Barrett Jacobsen

import ComposableArchitecture
import Foundation
import Network
import OSLog
import SupacodeShared
import Synchronization

private let logger = Logger(subsystem: "com.supacode.remote", category: "WebSocket")

struct WebSocketClient {
  var connect: @Sendable (NWEndpoint) async throws -> Void
  var send: @Sendable (RemoteMessage) async throws -> Void
  var receive: @Sendable () -> AsyncStream<RemoteMessage>
  var disconnect: @Sendable () -> Void
  var isConnected: @Sendable () -> Bool
}

extension WebSocketClient: DependencyKey {
  static let liveValue: WebSocketClient = {
    let manager = WebSocketManager()
    return WebSocketClient(
      connect: { endpoint in try await manager.connect(to: endpoint) },
      send: { message in try await manager.send(message) },
      receive: { manager.receive() },
      disconnect: { manager.disconnect() },
      isConnected: { manager.isConnected() },
    )
  }()

  static let testValue = WebSocketClient(
    connect: { _ in },
    send: { _ in },
    receive: { AsyncStream { $0.finish() } },
    disconnect: {},
    isConnected: { false },
  )
}

extension DependencyValues {
  var webSocketClient: WebSocketClient {
    get { self[WebSocketClient.self] }
    set { self[WebSocketClient.self] = newValue }
  }
}

// MARK: - Live Implementation

private final class WebSocketManager: Sendable {
  private struct State: Sendable {
    var connection: NWConnection?
    var continuation: AsyncStream<RemoteMessage>.Continuation?
  }

  private let state = Mutex(State())

  func connect(to endpoint: NWEndpoint) async throws {
    let parameters = NWParameters(tls: nil)
    let wsOptions = NWProtocolWebSocket.Options()
    parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
    let connection = NWConnection(to: endpoint, using: parameters)

    state.withLock { $0.connection = connection }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      connection.stateUpdateHandler = { [weak self] newState in
        switch newState {
        case .ready:
          connection.stateUpdateHandler = { [weak self] updatedState in
            if case .failed = updatedState {
              self?.handleDisconnect()
            } else if case .cancelled = updatedState {
              self?.handleDisconnect()
            }
          }
          continuation.resume()
        case .failed(let error):
          continuation.resume(throwing: error)
        case .cancelled:
          continuation.resume(throwing: CancellationError())
        default:
          break
        }
      }
      connection.start(queue: .main)
    }
  }

  func send(_ message: RemoteMessage) async throws {
    let connection = state.withLock { $0.connection }
    guard let connection else {
      throw WebSocketError.notConnected
    }

    let data = try JSONEncoder().encode(message)
    let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
    let context = NWConnection.ContentContext(
      identifier: "websocket",
      metadata: [metadata],
    )

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      connection.send(
        content: data,
        contentContext: context,
        isComplete: true,
        completion: NWConnection.SendCompletion.contentProcessed { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        },
      )
    }
  }

  func receive() -> AsyncStream<RemoteMessage> {
    let (stream, continuation) = AsyncStream.makeStream(of: RemoteMessage.self)
    state.withLock { state in
      state.continuation?.finish()
      state.continuation = continuation
    }
    receiveLoop()
    return stream
  }

  func disconnect() {
    let (connection, continuation) = state.withLock { state in
      let conn = state.connection
      let cont = state.continuation
      state.connection = nil
      state.continuation = nil
      return (conn, cont)
    }
    continuation?.finish()
    connection?.cancel()
  }

  func isConnected() -> Bool {
    state.withLock { connection in
      guard let conn = connection.connection else { return false }
      return conn.state == .ready
    }
  }

  private func receiveLoop() {
    let connection = state.withLock { $0.connection }
    guard let connection else { return }

    connection.receiveMessage { [weak self] (content: Data?, _: NWConnection.ContentContext?, _: Bool, error: NWError?) in
      guard let self else { return }
      if error != nil {
        self.handleDisconnect()
        return
      }
      guard let content else {
        self.handleDisconnect()
        return
      }

      do {
        let message = try JSONDecoder().decode(RemoteMessage.self, from: content)
        self.state.withLock { $0.continuation?.yield(message) }
      } catch {
        logger.warning("Failed to decode WebSocket message: \(error)")
      }
      self.receiveLoop()
    }
  }

  private func handleDisconnect() {
    let continuation = state.withLock { state in
      let cont = state.continuation
      state.connection = nil
      state.continuation = nil
      return cont
    }
    continuation?.finish()
  }
}

enum WebSocketError: Error, Sendable {
  case notConnected
}
