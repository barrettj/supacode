// Created by Barrett Jacobsen

import OSLog

nonisolated struct RemoteLogger: Sendable {
  private let category: String
  #if !DEBUG
    private let logger: Logger
  #endif

  init(_ category: String) {
    self.category = category
    #if !DEBUG
      self.logger = Logger(subsystem: "com.supacode.remote", category: category)
    #endif
  }

  func info(_ message: String) {
    #if DEBUG
      print("[Remote:\(category)] \(message)")
    #else
      logger.notice("\(message, privacy: .public)")
    #endif
  }

  func warning(_ message: String) {
    #if DEBUG
      print("[Remote:\(category)] \(message)")
    #else
      logger.warning("\(message, privacy: .public)")
    #endif
  }
}
