// Created by Barrett Jacobsen

import CryptoKit
import Foundation
import Network
import SupacodeShared

private let logger = SupaLogger("RemoteControl")

@MainActor
final class RemoteControlSession: Identifiable {
  let id = UUID()
  private let connection: NWConnection
  private let pin: String
  private var nonce: String?
  private(set) var isAuthenticated = false
  private var sessionToken: String?

  /// Called with (deviceName, sessionToken) on successful authentication.
  var onAuthenticated: ((String, String) -> Void)?
  var onDisconnected: (() -> Void)?
  var onCommandReceived: ((RemoteCommand) -> Void)?
  var onTerminalContentRequested: ((TerminalContentRequest) -> Void)?
  /// Validates a session token for reconnection. Returns device name if valid.
  var validateSessionToken: ((String) -> String?)?

  init(connection: NWConnection, pin: String) {
    self.connection = connection
    self.pin = pin
  }

  func start() {
    connection.start(queue: .main)
    let nonce = UUID().uuidString
    self.nonce = nonce
    let challenge = AuthChallenge(nonce: nonce, protocolVersion: RemoteMessage.currentVersion)
    do {
      let message = try RemoteMessage(type: .authChallenge, payload: challenge)
      send(message)
    } catch {
      logger.warning("Failed to encode auth challenge: \(error)")
    }
    receiveLoop()
  }

  func disconnect() {
    connection.cancel()
    onDisconnected?()
  }

  func send(_ message: RemoteMessage) {
    let data: Data
    do {
      data = try JSONEncoder().encode(message)
    } catch {
      logger.warning("Failed to encode message: \(error)")
      return
    }
    let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
    let context = NWConnection.ContentContext(
      identifier: "websocket",
      metadata: [metadata],
    )
    connection.send(content: data, contentContext: context, completion: .contentProcessed({ error in
      if let error {
        logger.warning("Failed to send message: \(error)")
      }
    }))
  }

  private func receiveLoop() {
    connection.receiveMessage { [weak self] content, _, _, error in
      guard let self else { return }
      if let error {
        Task { @MainActor in
          logger.warning("WebSocket receive error: \(error)")
          self.disconnect()
        }
        return
      }
      guard let content else {
        Task { @MainActor in
          self.disconnect()
        }
        return
      }
      Task { @MainActor in
        self.handleMessage(content)
        self.receiveLoop()
      }
    }
  }

  private func handleMessage(_ data: Data) {
    let message: RemoteMessage
    do {
      message = try JSONDecoder().decode(RemoteMessage.self, from: data)
    } catch {
      logger.warning("Failed to decode incoming message: \(error)")
      return
    }

    switch message.type {
    case .authRequest:
      handleAuthRequest(message)
    case .command:
      guard isAuthenticated else { return }
      do {
        let command = try message.decode(RemoteCommand.self)
        onCommandReceived?(command)
      } catch {
        logger.warning("Failed to decode command: \(error)")
      }
    case .terminalContentRequest:
      guard isAuthenticated else { return }
      do {
        let request = try message.decode(TerminalContentRequest.self)
        onTerminalContentRequested?(request)
      } catch {
        logger.warning("Failed to decode terminal content request: \(error)")
      }
    case .pong:
      break
    default:
      break
    }
  }

  private func handleAuthRequest(_ message: RemoteMessage) {
    let request: AuthRequest
    do {
      request = try message.decode(AuthRequest.self)
    } catch {
      logger.warning("Failed to decode auth request: \(error)")
      sendAuthFailure("Invalid request")
      return
    }
    guard let nonce else {
      sendAuthFailure("Invalid request")
      return
    }

    // Check session token for reconnection via server-managed tokens
    if let token = request.sessionToken, let deviceName = validateSessionToken?(token) {
      authenticateSuccess(deviceName: deviceName)
      return
    }

    // If PIN is empty, auth is disabled (open access)
    if pin.isEmpty {
      authenticateSuccess(deviceName: request.deviceName)
      return
    }

    // Verify PIN hash: SHA256(pin + nonce)
    let inputData = Data((pin + nonce).utf8)
    let hash = SHA256.hash(data: inputData)
    let expected = hash.map { String(format: "%02x", $0) }.joined()
    guard request.hash == expected else {
      sendAuthFailure("Invalid PIN")
      return
    }

    authenticateSuccess(deviceName: request.deviceName)
  }

  private func authenticateSuccess(deviceName: String) {
    let token = UUID().uuidString
    let response = AuthResponse(success: true, sessionToken: token, error: nil)
    do {
      let message = try RemoteMessage(type: .authResponse, payload: response)
      send(message)
      isAuthenticated = true
      sessionToken = token
      onAuthenticated?(deviceName, token)
    } catch {
      logger.warning("Failed to encode auth success response: \(error)")
      disconnect()
    }
  }

  private func sendAuthFailure(_ reason: String) {
    let response = AuthResponse(success: false, sessionToken: nil, error: reason)
    do {
      let message = try RemoteMessage(type: .authResponse, payload: response)
      send(message)
    } catch {
      logger.warning("Failed to encode auth failure response: \(error)")
    }
    // Close connection after failed auth to prevent socket leaks
    disconnect()
  }
}
