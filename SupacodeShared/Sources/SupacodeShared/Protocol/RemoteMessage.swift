// Created by Barrett Jacobsen

import Foundation

public struct RemoteMessage: Sendable {
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

// MARK: - Codable

// Custom Codable implementation that embeds the payload as inline JSON
// instead of Base64-encoded Data, reducing message sizes on the wire.
extension RemoteMessage: Codable {
  enum CodingKeys: String, CodingKey {
    case version, type, id, payload
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(id, forKey: .id)
    if payload.isEmpty {
      try container.encode(JSONFragment(value: [:] as [String: Any]), forKey: .payload)
    } else {
      let jsonObject = try JSONSerialization.jsonObject(with: payload)
      try container.encode(JSONFragment(value: jsonObject), forKey: .payload)
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    type = try container.decode(MessageType.self, forKey: .type)
    id = try container.decodeIfPresent(UUID.self, forKey: .id)
    let fragment = try container.decode(JSONFragment.self, forKey: .payload)
    payload = try JSONSerialization.data(withJSONObject: fragment.value)
  }
}

// MARK: - JSONFragment

/// Wraps an arbitrary JSON value so it can be encoded/decoded inline
/// within a parent `Codable` container, avoiding Base64 encoding of nested JSON.
private struct JSONFragment: Codable {
  let value: Any

  init(value: Any) {
    self.value = value
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let dict = try? container.decode([String: JSONFragment].self) {
      value = dict.mapValues(\.value)
    } else if let array = try? container.decode([JSONFragment].self) {
      value = array.map(\.value)
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let int = try? container.decode(Int.self) {
      // Decode Int before Bool because JSONDecoder can decode 0/1 as Bool
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if container.decodeNil() {
      value = NSNull()
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let dict as [String: Any]:
      try container.encode(dict.mapValues { JSONFragment(value: $0) })
    case let array as [Any]:
      try container.encode(array.map { JSONFragment(value: $0) })
    case let string as String:
      try container.encode(string)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let bool as Bool:
      // NSNumber bridges Bool and numeric types; encode Bool after Int/Double
      // so that numeric values are preserved as numbers.
      try container.encode(bool)
    case is NSNull:
      try container.encodeNil()
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported JSON value")
      )
    }
  }
}
