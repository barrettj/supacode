// Created by Barrett Jacobsen

public enum RemoteCommand: Codable, Sendable, Equatable {
  // Worktree navigation
  case selectWorktree(worktreeID: String)
  case selectNextWorktree
  case selectPreviousWorktree

  // Tab management
  case selectTab(worktreeID: String, tabID: String)
  case createTab(worktreeID: String)
  case closeTab(worktreeID: String, tabID: String)

  // Split management
  case splitHorizontal(worktreeID: String, tabID: String, surfaceID: String)
  case splitVertical(worktreeID: String, tabID: String, surfaceID: String)
  case closeSurface(worktreeID: String, tabID: String, surfaceID: String)
  case focusSurface(worktreeID: String, tabID: String, surfaceID: String)
  case equalizeSplits(worktreeID: String, tabID: String)

  // Terminal input
  case sendInput(surfaceID: String, text: String, appendNewline: Bool)
  case sendKey(surfaceID: String, key: RemoteKeyEvent)

  // Notifications
  case markNotificationsRead(worktreeID: String)

  // Search
  case startSearch(worktreeID: String, query: String)
  case navigateSearchNext(worktreeID: String)
  case navigateSearchPrevious(worktreeID: String)
  case endSearch(worktreeID: String)

  // Run scripts
  case runScript(worktreeID: String, script: String)
  case stopRunScript(worktreeID: String)
}
