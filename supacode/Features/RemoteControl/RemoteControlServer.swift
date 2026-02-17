// Created by Barrett Jacobsen

import Foundation
import Network
import SupacodeShared

private let logger = SupaLogger("RemoteControl")

@MainActor @Observable
final class RemoteControlServer {
  private(set) var isRunning = false
  private(set) var connectedDevices: [ConnectedDevice] = []
  private var listener: NWListener?
  private var sessions: [UUID: RemoteControlSession] = [:]
  private var pin: String = ""

  struct ConnectedDevice: Identifiable, Equatable {
    let id: UUID
    let deviceName: String
    let connectedAt: Date
  }

  func start(pin: String, port: UInt16 = 7483, name: String = "Supacode") throws {
    guard !isRunning else { return }
    self.pin = pin

    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true
    let wsOptions = NWProtocolWebSocket.Options()
    parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

    let newListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? 7483)
    let serviceName = name.isEmpty ? "Supacode" : name
    newListener.service = NWListener.Service(
      name: serviceName,
      type: "_supacode._tcp"
    )
    newListener.stateUpdateHandler = { [weak self] state in
      Task { @MainActor [weak self] in
        self?.handleListenerStateChange(state)
      }
    }
    newListener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor [weak self] in
        self?.handleNewConnection(connection)
      }
    }
    newListener.start(queue: .main)
    listener = newListener
    isRunning = true
    logger.info("Remote control server started")
  }

  func stop() {
    listener?.cancel()
    listener = nil
    for session in sessions.values {
      session.disconnect()
    }
    sessions.removeAll()
    connectedDevices.removeAll()
    isRunning = false
    logger.info("Remote control server stopped")
  }

  func disconnect(deviceID: UUID) {
    sessions[deviceID]?.disconnect()
    sessions.removeValue(forKey: deviceID)
    connectedDevices.removeAll { $0.id == deviceID }
  }

  func broadcast(_ message: RemoteMessage) {
    for session in sessions.values where session.isAuthenticated {
      session.send(message)
    }
  }

  func sendToSession(_ sessionID: UUID, message: RemoteMessage) {
    sessions[sessionID]?.send(message)
  }

  var onCommandReceived: ((UUID, RemoteCommand) -> Void)?
  var onTerminalContentRequested: ((UUID, TerminalContentRequest) -> Void)?
  var onSessionAuthenticated: ((UUID) -> Void)?
  var onSessionDisconnected: ((UUID) -> Void)?

  private func handleListenerStateChange(_ state: NWListener.State) {
    switch state {
    case .ready:
      if let port = listener?.port {
        logger.info("Remote control server listening on port \(port)")
      }
    case .failed(let error):
      logger.warning("Remote control server failed: \(error)")
      stop()
    default:
      break
    }
  }

  private func handleNewConnection(_ connection: NWConnection) {
    let session = RemoteControlSession(connection: connection, pin: pin)
    let id = session.id
    sessions[id] = session
    session.onAuthenticated = { [weak self] deviceName in
      self?.connectedDevices.append(ConnectedDevice(
        id: id,
        deviceName: deviceName,
        connectedAt: Date(),
      ))
      logger.info("Remote device connected: \(deviceName)")
      self?.onSessionAuthenticated?(id)
    }
    session.onDisconnected = { [weak self] in
      self?.sessions.removeValue(forKey: id)
      self?.connectedDevices.removeAll { $0.id == id }
      self?.onSessionDisconnected?(id)
      logger.info("Remote device disconnected: \(id)")
    }
    session.onCommandReceived = { [weak self] command in
      self?.onCommandReceived?(id, command)
    }
    session.onTerminalContentRequested = { [weak self] request in
      self?.onTerminalContentRequested?(id, request)
    }
    session.start()
  }
}
