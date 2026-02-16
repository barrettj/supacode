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

  var onAuthenticated: ((String) -> Void)?
  var onDisconnected: (() -> Void)?
  var onCommandReceived: ((RemoteCommand) -> Void)?
  var onTerminalContentRequested: ((TerminalContentRequest) -> Void)?

  init(connection: NWConnection, pin: String) {
    self.connection = connection
    self.pin = pin
  }

  func start() {
    connection.start(queue: .main)
    let nonce = UUID().uuidString
    self.nonce = nonce
    let challenge = AuthChallenge(nonce: nonce)
    if let message = try? RemoteMessage(type: .authChallenge, payload: challenge) {
      send(message)
    }
    receiveLoop()
  }

  func disconnect() {
    connection.cancel()
    onDisconnected?()
  }

  func send(_ message: RemoteMessage) {
    guard let data = try? JSONEncoder().encode(message) else { return }
    let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
    let context = NWConnection.ContentContext(
      identifier: "websocket",
      metadata: [metadata],
    )
    connection.send(content: data, contentContext: context, completion: .idempotent)
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
    guard let message = try? JSONDecoder().decode(RemoteMessage.self, from: data) else { return }

    switch message.type {
    case .authRequest:
      handleAuthRequest(message)
    case .command:
      guard isAuthenticated else { return }
      if let command = try? message.decode(RemoteCommand.self) {
        onCommandReceived?(command)
      }
    case .terminalContentRequest:
      guard isAuthenticated else { return }
      if let request = try? message.decode(TerminalContentRequest.self) {
        onTerminalContentRequested?(request)
      }
    case .pong:
      break
    default:
      break
    }
  }

  private func handleAuthRequest(_ message: RemoteMessage) {
    guard let request = try? message.decode(AuthRequest.self),
      let nonce
    else {
      sendAuthFailure("Invalid request")
      return
    }

    // Check session token for reconnection
    if let token = request.sessionToken, token == sessionToken {
      authenticateSuccess(deviceName: request.deviceName)
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
    isAuthenticated = true
    let token = UUID().uuidString
    sessionToken = token
    let response = AuthResponse(success: true, sessionToken: token, error: nil)
    if let message = try? RemoteMessage(type: .authResponse, payload: response) {
      send(message)
    }
    onAuthenticated?(deviceName)
  }

  private func sendAuthFailure(_ error: String) {
    let response = AuthResponse(success: false, sessionToken: nil, error: error)
    if let message = try? RemoteMessage(type: .authResponse, payload: response) {
      send(message)
    }
  }
}
