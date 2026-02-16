// Created by Barrett Jacobsen

public struct TerminalContentRequest: Codable, Sendable, Equatable {
  public let surfaceID: String
  public let action: ContentAction

  public enum ContentAction: String, Codable, Sendable, Equatable {
    case startStreaming
    case stopStreaming
    case requestOnce
  }

  public init(surfaceID: String, action: ContentAction) {
    self.surfaceID = surfaceID
    self.action = action
  }
}

public struct TerminalContent: Codable, Sendable, Equatable {
  public let surfaceID: String
  public let lines: [String]
  public let cursorRow: Int?
  public let cursorCol: Int?
  public let rows: Int
  public let cols: Int
  public let scrollbackOffset: Int

  public init(
    surfaceID: String,
    lines: [String],
    cursorRow: Int?,
    cursorCol: Int?,
    rows: Int,
    cols: Int,
    scrollbackOffset: Int
  ) {
    self.surfaceID = surfaceID
    self.lines = lines
    self.cursorRow = cursorRow
    self.cursorCol = cursorCol
    self.rows = rows
    self.cols = cols
    self.scrollbackOffset = scrollbackOffset
  }
}
