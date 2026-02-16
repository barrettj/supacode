// Created by Barrett Jacobsen

public struct RemoteKeyEvent: Codable, Sendable, Equatable {
  public let key: RemoteKey
  public let modifiers: RemoteModifiers
  public let characterValue: String?

  public enum RemoteKey: String, Codable, Sendable, Equatable {
    case enter
    case tab
    case escape
    case backspace
    case delete
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case home
    case end
    case pageUp
    case pageDown
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
    case space
    case character
  }

  public struct RemoteModifiers: OptionSet, Codable, Sendable, Equatable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    public static let ctrl = RemoteModifiers(rawValue: 1 << 0)
    public static let alt = RemoteModifiers(rawValue: 1 << 1)
    public static let shift = RemoteModifiers(rawValue: 1 << 2)
    public static let superKey = RemoteModifiers(rawValue: 1 << 3)
  }

  public init(key: RemoteKey, modifiers: RemoteModifiers, characterValue: String?) {
    self.key = key
    self.modifiers = modifiers
    self.characterValue = characterValue
  }
}
