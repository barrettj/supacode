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
    worktreeInfoByID: [Worktree.ID: WorktreeInfoEntry] = [:],
    worktreeOrderByRepository: [String: [Worktree.ID]] = [:],
    archivedWorktreeIDs: Set<Worktree.ID> = [],
    repositoryOrderIDs: [Repository.ID] = [],
    collapsedRepositoryIDs: [Repository.ID] = []
  ) -> StateSnapshot {
    // Sort repositories to match mac sidebar order
    let sortedRepositories: [Repository]
    if repositoryOrderIDs.isEmpty {
      sortedRepositories = repositories
    } else {
      let repoByID = Dictionary(uniqueKeysWithValues: repositories.map { ($0.id, $0) })
      var ordered: [Repository] = []
      var seen: Set<Repository.ID> = []
      for id in repositoryOrderIDs {
        if let repo = repoByID[id], seen.insert(id).inserted {
          ordered.append(repo)
        }
      }
      for repo in repositories where seen.insert(repo.id).inserted {
        ordered.append(repo)
      }
      sortedRepositories = ordered
    }

    var worktreeStates: [String: RemoteWorktreeState] = [:]
    let allWorktrees = sortedRepositories.flatMap(\.worktrees)

    for worktree in allWorktrees {
      let isPinned = pinnedWorktreeIDs.contains(worktree.id)
      let isMain = worktree.workingDirectory.standardizedFileURL
        == worktree.repositoryRootURL.standardizedFileURL
      if let state = terminalManager.stateIfExists(for: worktree.id) {
        worktreeStates[worktree.id] = serializeWorktreeState(
          state,
          worktree: worktree,
          isPinned: isPinned,
          isMainWorktree: isMain,
          info: worktreeInfoByID[worktree.id],
        )
      } else {
        worktreeStates[worktree.id] = RemoteWorktreeState(
          worktree: serialize(worktree, isPinned: isPinned, isMainWorktree: isMain, info: worktreeInfoByID[worktree.id]),
          tabs: [],
          selectedTabID: nil,
          splitTrees: [:],
          focusedSurfaceByTab: [:],
          notifications: [],
          taskStatus: .idle,
          isRunScriptRunning: false,
          hasUnseenNotifications: false,
        )
      }
    }

    let orderedRepositories = sortedRepositories.map { repository in
      serializeRepository(
        repository,
        pinnedWorktreeIDs: pinnedWorktreeIDs,
        worktreeOrderByRepository: worktreeOrderByRepository,
        archivedWorktreeIDs: archivedWorktreeIDs,
      )
    }

    let allRepoIDs = Set(sortedRepositories.map(\.id))
    let collapsedSet = Set(collapsedRepositoryIDs).intersection(allRepoIDs)
    let expandedSet = allRepoIDs.subtracting(collapsedSet)

    return StateSnapshot(
      repositories: orderedRepositories,
      selectedWorktreeID: selectedWorktreeID,
      worktreeStates: worktreeStates,
      expandedRepositoryIDs: expandedSet,
    )
  }

  private static func serializeRepository(
    _ repository: Repository,
    pinnedWorktreeIDs: [Worktree.ID],
    worktreeOrderByRepository: [String: [Worktree.ID]],
    archivedWorktreeIDs: Set<Worktree.ID>
  ) -> RemoteRepository {
    let pinnedSet = Set(pinnedWorktreeIDs)

    // Main worktree first
    var ordered: [Worktree.ID] = []
    if let mainWorktree = repository.worktrees.first(where: {
      $0.workingDirectory.standardizedFileURL == $0.repositoryRootURL.standardizedFileURL
    }) {
      if !archivedWorktreeIDs.contains(mainWorktree.id) {
        ordered.append(mainWorktree.id)
      }
    }

    // Pinned worktrees (in pinned order)
    let mainID = ordered.first
    let worktreeIDSet = Set(repository.worktrees.map(\.id))
    for id in pinnedWorktreeIDs {
      if !archivedWorktreeIDs.contains(id),
        worktreeIDSet.contains(id),
        id != mainID
      {
        ordered.append(id)
      }
    }

    // Unpinned worktrees (using custom order)
    let customOrder = worktreeOrderByRepository[repository.id] ?? []
    let available = repository.worktrees.filter { worktree in
      worktree.id != mainID
        && !pinnedSet.contains(worktree.id)
        && !archivedWorktreeIDs.contains(worktree.id)
    }
    let availableIDs = Set(available.map(\.id))
    let orderedIDSet = Set(customOrder)
    var seen: Set<Worktree.ID> = []
    // Worktrees not in custom order come first
    for worktree in available where !orderedIDSet.contains(worktree.id) {
      if seen.insert(worktree.id).inserted {
        ordered.append(worktree.id)
      }
    }
    // Then worktrees in custom order
    for id in customOrder {
      if availableIDs.contains(id), seen.insert(id).inserted {
        ordered.append(id)
      }
    }

    return RemoteRepository(
      id: repository.id,
      name: repository.name,
      worktreeIDs: ordered,
    )
  }
}
