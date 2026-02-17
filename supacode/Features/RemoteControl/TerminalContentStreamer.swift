// Created by Barrett Jacobsen

import Foundation
import GhosttyKit
import SupacodeShared

private let logger = SupaLogger("TerminalContentStreamer")

@MainActor
final class TerminalContentStreamer {
  private struct StreamKey: Hashable {
    let sessionID: UUID
    let surfaceID: String
  }

  private var streamingTasks: [StreamKey: Task<Void, Never>] = [:]
  private let terminalManager: WorktreeTerminalManager

  init(terminalManager: WorktreeTerminalManager) {
    self.terminalManager = terminalManager
  }

  func startStreaming(
    sessionID: UUID,
    surfaceID: String,
    send: @escaping @MainActor (TerminalContent) -> Void
  ) {
    let key = StreamKey(sessionID: sessionID, surfaceID: surfaceID)
    streamingTasks[key]?.cancel()

    streamingTasks[key] = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        if let content = self?.readContent(surfaceID: surfaceID) {
          send(content)
        }
        try? await Task.sleep(for: .milliseconds(300))
      }
    }
  }

  func stopStreaming(sessionID: UUID, surfaceID: String) {
    let key = StreamKey(sessionID: sessionID, surfaceID: surfaceID)
    streamingTasks[key]?.cancel()
    streamingTasks.removeValue(forKey: key)
  }

  func stopAllStreaming(sessionID: UUID) {
    for (key, task) in streamingTasks where key.sessionID == sessionID {
      task.cancel()
      streamingTasks.removeValue(forKey: key)
    }
  }

  func stopAllStreaming() {
    for task in streamingTasks.values {
      task.cancel()
    }
    streamingTasks.removeAll()
  }

  func readContentOnce(surfaceID: String) -> TerminalContent? {
    readContent(surfaceID: surfaceID)
  }

  // MARK: - Private

  private func findSurfaceView(surfaceID: String) -> GhosttySurfaceView? {
    guard let uuid = UUID(uuidString: surfaceID) else { return nil }
    for (_, state) in terminalManager.allStates() {
      if let surface = state.allSurfaces[uuid] {
        return surface
      }
    }
    return nil
  }

  private func readContent(surfaceID: String) -> TerminalContent? {
    guard let surfaceView = findSurfaceView(surfaceID: surfaceID),
      let surface = surfaceView.surface
    else { return nil }

    let size = ghostty_surface_size(surface)
    let rows = Int(size.rows)
    let cols = Int(size.columns)

    guard rows > 0, cols > 0 else { return nil }

    // Build a selection covering the entire viewport (row 0 to rows-1)
    let topLeft = ghostty_point_s(
      tag: GHOSTTY_POINT_VIEWPORT,
      coord: GHOSTTY_POINT_COORD_TOP_LEFT,
      x: 0,
      y: 0
    )
    let bottomRight = ghostty_point_s(
      tag: GHOSTTY_POINT_VIEWPORT,
      coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT,
      x: UInt32(cols - 1),
      y: UInt32(rows - 1)
    )
    let selection = ghostty_selection_s(
      top_left: topLeft,
      bottom_right: bottomRight,
      rectangle: false
    )

    var text = ghostty_text_s()
    let success = ghostty_surface_read_text(surface, selection, &text)

    guard success, let textPtr = text.text else {
      return TerminalContent(
        surfaceID: surfaceID,
        lines: [],
        cursorRow: nil,
        cursorCol: nil,
        rows: rows,
        cols: cols,
        scrollbackOffset: 0,
      )
    }

    let rawPtr = UnsafeRawPointer(textPtr)
    let buffer = UnsafeBufferPointer(start: rawPtr.assumingMemoryBound(to: UInt8.self), count: Int(text.text_len))
    let content = String(decoding: buffer, as: UTF8.self)

    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let result = TerminalContent(
      surfaceID: surfaceID,
      lines: lines,
      cursorRow: nil,
      cursorCol: nil,
      rows: rows,
      cols: cols,
      scrollbackOffset: 0,
    )

    ghostty_surface_free_text(surface, &text)

    return result
  }
}
