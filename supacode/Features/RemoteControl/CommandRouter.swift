// Created by Barrett Jacobsen

import Foundation
import GhosttyKit
import SupacodeShared

@MainActor
struct CommandRouter {
  let terminalManager: WorktreeTerminalManager
  let repositories: () -> [Repository]
  let onSelectWorktree: ((String) -> Void)?
  let onSelectNextWorktree: (() -> Void)?
  let onSelectPreviousWorktree: (() -> Void)?

  func route(_ command: RemoteCommand) {
    switch command {
    case .selectWorktree(let worktreeID):
      onSelectWorktree?(worktreeID)

    case .selectNextWorktree:
      onSelectNextWorktree?()

    case .selectPreviousWorktree:
      onSelectPreviousWorktree?()

    case .createTab(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.createTab()

    case .closeTab(_, let tabID):
      guard let uuid = UUID(uuidString: tabID) else { return }
      let terminalTabID = TerminalTabID(rawValue: uuid)
      // Find the state containing this tab and close it
      for (_, state) in terminalManager.allStates() {
        if state.tabManager.tabs.contains(where: { $0.id == terminalTabID }) {
          state.closeTab(terminalTabID)
          return
        }
      }

    case .selectTab(let worktreeID, let tabID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      guard let uuid = UUID(uuidString: tabID) else { return }
      state.selectTab(TerminalTabID(rawValue: uuid))

    case .splitHorizontal(let worktreeID, _, let surfaceID):
      performSplit(worktreeID: worktreeID, surfaceID: surfaceID, direction: .right)

    case .splitVertical(let worktreeID, _, let surfaceID):
      performSplit(worktreeID: worktreeID, surfaceID: surfaceID, direction: .down)

    case .closeSurface(let worktreeID, _, let surfaceID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      guard let uuid = UUID(uuidString: surfaceID),
        let surfaceView = state.allSurfaces[uuid]
      else { return }
      surfaceView.performBindingAction("close_surface")

    case .focusSurface(let worktreeID, _, let surfaceID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      guard let uuid = UUID(uuidString: surfaceID) else { return }
      _ = state.focusSurface(id: uuid)

    case .equalizeSplits(let worktreeID, let tabID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      guard let uuid = UUID(uuidString: tabID) else { return }
      let terminalTabID = TerminalTabID(rawValue: uuid)
      // Find any surface in the tab to perform equalize on
      if let tree = state.splitTrees[terminalTabID],
        let root = tree.root
      {
        let surfaceID = root.leftmostLeaf().id
        _ = state.performSplitAction(.equalizeSplits, for: surfaceID)
      }

    case .sendInput(let surfaceID, let text, let appendNewline):
      let fullText = appendNewline ? text + "\n" : text
      sendTextToSurface(surfaceID: surfaceID, text: fullText)

    case .sendKey(let surfaceID, let keyEvent):
      handleKeyEvent(surfaceID: surfaceID, keyEvent: keyEvent)

    case .startSearch(let worktreeID, let query):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.performBindingActionOnFocusedSurface("start_search")
      if !query.isEmpty {
        _ = state.performBindingActionOnFocusedSurface("search:\(query)")
      }

    case .navigateSearchNext(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.navigateSearchOnFocusedSurface(.next)

    case .navigateSearchPrevious(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.navigateSearchOnFocusedSurface(.previous)

    case .endSearch(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.performBindingActionOnFocusedSurface("end_search")

    case .runScript(let worktreeID, let script):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.runScript(script)

    case .stopRunScript(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      _ = state.stopRunScript()

    case .markNotificationsRead(let worktreeID):
      guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
      state.markAllNotificationsRead()
    }
  }

  private func findSurfaceView(_ surfaceID: String) -> GhosttySurfaceView? {
    guard let uuid = UUID(uuidString: surfaceID) else { return nil }
    for (_, state) in terminalManager.allStates() {
      if let surface = state.allSurfaces[uuid] {
        return surface
      }
    }
    return nil
  }

  private func performSplit(worktreeID: String, surfaceID: String, direction: GhosttySplitAction.NewDirection) {
    guard let state = terminalManager.stateIfExists(for: worktreeID) else { return }
    guard let uuid = UUID(uuidString: surfaceID) else { return }
    _ = state.performSplitAction(.newSplit(direction: direction), for: uuid)
  }

  private func sendTextToSurface(surfaceID: String, text: String) {
    guard let surfaceView = findSurfaceView(surfaceID),
      let surface = surfaceView.surface
    else { return }
    let len = text.utf8CString.count
    if len == 0 { return }
    text.withCString { ptr in
      ghostty_surface_text(surface, ptr, UInt(len - 1))
    }
  }

  private func handleKeyEvent(surfaceID: String, keyEvent: RemoteKeyEvent) {
    guard let surfaceView = findSurfaceView(surfaceID) else { return }

    if let characterValue = keyEvent.characterValue {
      guard let surface = surfaceView.surface else { return }
      let len = characterValue.utf8CString.count
      if len == 0 { return }
      characterValue.withCString { ptr in
        ghostty_surface_text(surface, ptr, UInt(len - 1))
      }
    }
    // TODO: Handle special key mappings (RemoteKey enum -> Ghostty key codes)
  }
}
