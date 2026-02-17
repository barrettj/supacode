// Created by Barrett Jacobsen

import Foundation
import SupacodeShared

@MainActor
enum StateSerializer {
  static func serialize(_ repository: Repository) -> RemoteRepository {
    RemoteRepository(
      id: repository.id,
      name: repository.name,
      worktreeIDs: repository.worktrees.map(\.id),
    )
  }

  static func serialize(
    _ worktree: Worktree,
    isPinned: Bool = false,
    isMainWorktree: Bool = false,
    info: WorktreeInfoEntry? = nil
  ) -> RemoteWorktree {
    RemoteWorktree(
      id: worktree.id,
      name: worktree.name,
      detail: worktree.detail,
      repositoryID: worktree.repositoryRootURL.standardizedFileURL.path(percentEncoded: false),
      isPinned: isPinned,
      isMainWorktree: isMainWorktree,
      addedLines: info?.addedLines,
      removedLines: info?.removedLines,
      pullRequestNumber: info?.pullRequest?.number,
      pullRequestState: info?.pullRequest?.state,
    )
  }

  static func serialize(_ tab: TerminalTabItem) -> RemoteTab {
    RemoteTab(
      id: tab.id.rawValue.uuidString,
      title: tab.title,
      icon: tab.icon,
      isDirty: tab.isDirty,
    )
  }

  static func serialize(_ notification: WorktreeTerminalNotification) -> RemoteNotification {
    RemoteNotification(
      id: notification.id.uuidString,
      surfaceID: notification.surfaceId.uuidString,
      title: notification.title,
      body: notification.body,
      isRead: notification.isRead,
    )
  }

  static func serialize(_ status: WorktreeTaskStatus) -> RemoteTaskStatus {
    switch status {
    case .idle: return .idle
    case .running: return .running
    }
  }

  static func serializeSplitTree(_ tree: SplitTree<GhosttySurfaceView>) -> RemoteSplitTree {
    RemoteSplitTree(root: tree.root.map { serializeNode($0) })
  }

  private static func serializeNode(_ node: SplitTree<GhosttySurfaceView>.Node) -> RemoteSplitTree.Node {
    switch node {
    case .leaf(let view):
      return .leaf(surfaceID: view.id.uuidString)
    case .split(let split):
      return .split(
        RemoteSplitTree.Split(
          direction: split.direction == .horizontal ? .horizontal : .vertical,
          ratio: split.ratio,
          left: serializeNode(split.left),
          right: serializeNode(split.right),
        )
      )
    }
  }

  static func serializeSurface(_ surface: GhosttySurfaceView) -> RemoteSurface {
    let state = surface.bridge.state
    return RemoteSurface(
      id: surface.id.uuidString,
      title: state.title,
      pwd: state.pwd,
      bellCount: state.bellCount,
    )
  }

  static func serializeWorktreeState(
    _ state: WorktreeTerminalState,
    worktree: Worktree,
    isPinned: Bool = false,
    isMainWorktree: Bool = false,
    info: WorktreeInfoEntry? = nil
  ) -> RemoteWorktreeState {
    let tabs = state.tabManager.tabs.map { serialize($0) }
    let selectedTabID = state.tabManager.selectedTabId?.rawValue.uuidString

    var splitTrees: [String: RemoteSplitTree] = [:]
    var focusedSurfaceByTab: [String: String] = [:]
    var surfaceMap: [String: RemoteSurface] = [:]

    for (tabId, tree) in state.splitTrees {
      let tabIDStr = tabId.rawValue.uuidString
      splitTrees[tabIDStr] = serializeSplitTree(tree)
      if let focusedId = state.focusedSurfaces[tabId] {
        focusedSurfaceByTab[tabIDStr] = focusedId.uuidString
      }
      for surface in tree.leaves() {
        surfaceMap[surface.id.uuidString] = serializeSurface(surface)
      }
    }

    return RemoteWorktreeState(
      worktree: serialize(worktree, isPinned: isPinned, isMainWorktree: isMainWorktree, info: info),
      tabs: tabs,
      selectedTabID: selectedTabID,
      splitTrees: splitTrees,
      focusedSurfaceByTab: focusedSurfaceByTab,
      notifications: state.notifications.map { serialize($0) },
      taskStatus: serialize(state.taskStatus),
      isRunScriptRunning: state.isRunScriptRunning,
      hasUnseenNotifications: state.hasUnseenNotification,
      surfaces: surfaceMap,
    )
  }

  static func serializeSnapshot(
    repositories: [Repository],
    selectedWorktreeID: Worktree.ID?,
    terminalManager: WorktreeTerminalManager,
    pinnedWorktreeIDs: [Worktree.ID] = [],
    worktreeInfoByID: [Worktree.ID: WorktreeInfoEntry] = [:]
  ) -> StateSnapshot {
    var worktreeStates: [String: RemoteWorktreeState] = [:]
    let allWorktrees = repositories.flatMap(\.worktrees)

    for worktree in allWorktrees {
      if let state = terminalManager.stateIfExists(for: worktree.id) {
        let isPinned = pinnedWorktreeIDs.contains(worktree.id)
        let isMain = worktree.workingDirectory.standardizedFileURL
          == worktree.repositoryRootURL.standardizedFileURL
        worktreeStates[worktree.id] = serializeWorktreeState(
          state,
          worktree: worktree,
          isPinned: isPinned,
          isMainWorktree: isMain,
          info: worktreeInfoByID[worktree.id],
        )
      }
    }

    return StateSnapshot(
      repositories: repositories.map { serialize($0) },
      selectedWorktreeID: selectedWorktreeID,
      worktreeStates: worktreeStates,
    )
  }
}
