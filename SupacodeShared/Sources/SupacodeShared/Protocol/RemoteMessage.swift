// Created by Barrett Jacobsen

import Foundation

public struct RemoteMessage: Codable, Sendable {
  public static let currentVersion = 1

  public let version: Int
  public let type: MessageType
  public let id: UUID?
  public let payload: Data

  public enum MessageType: String, Codable, Sendable {
    case authChallenge
    case authRequest
    case authResponse
    case stateSnapshot
    case stateDelta
    case command
    case terminalContentRequest
    case terminalContent
    case ping
    case pong
  }

  public init<T: Encodable>(type: MessageType, payload: T, id: UUID? = nil) throws {
    self.version = Self.currentVersion
    self.type = type
    self.id = id
    self.payload = try JSONEncoder().encode(payload)
  }

  public init(type: MessageType, id: UUID? = nil) {
    self.version = Self.currentVersion
    self.type = type
    self.id = id
    self.payload = Data()
  }

  public func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: payload)
  }
}
