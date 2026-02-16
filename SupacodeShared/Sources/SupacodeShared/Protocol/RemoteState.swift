// Created by Barrett Jacobsen

public struct RemoteState: Equatable, Sendable {
  public var repositories: [RemoteRepository]
  public var selectedWorktreeID: String?
  public var worktreeStates: [String: RemoteWorktreeState]

  public init(snapshot: StateSnapshot) {
    self.repositories = snapshot.repositories
    self.selectedWorktreeID = snapshot.selectedWorktreeID
    self.worktreeStates = snapshot.worktreeStates
  }

  public mutating func apply(_ delta: StateDelta) {
    switch delta {
    case .repositoriesChanged(let repos):
      repositories = repos

    case .worktreeAdded(let state):
      worktreeStates[state.worktree.id] = state

    case .worktreeRemoved(let worktreeID):
      worktreeStates.removeValue(forKey: worktreeID)

    case .selectedWorktreeChanged(let worktreeID):
      selectedWorktreeID = worktreeID

    case .tabAdded(let worktreeID, let tab):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.tabs.append(tab)
      worktreeStates[worktreeID] = wState

    case .tabRemoved(let worktreeID, let tabID):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.tabs.removeAll { $0.id == tabID }
      worktreeStates[worktreeID] = wState

    case .tabUpdated(let worktreeID, let tabID, let update):
      guard var wState = worktreeStates[worktreeID],
        let index = wState.tabs.firstIndex(where: { $0.id == tabID }) else { return }
      let old = wState.tabs[index]
      wState.tabs[index] = RemoteTab(
        id: old.id,
        title: update.title ?? old.title,
        icon: update.icon ?? old.icon,
        isDirty: update.isDirty ?? old.isDirty,
      )
      worktreeStates[worktreeID] = wState

    case .selectedTabChanged(let worktreeID, let tabID):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.selectedTabID = tabID
      worktreeStates[worktreeID] = wState

    case .splitTreeChanged(let worktreeID, let tabID, let tree):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.splitTrees[tabID] = tree
      worktreeStates[worktreeID] = wState

    case .surfaceMetadataUpdated(let surfaceID, let update):
      for (wtID, var wState) in worktreeStates {
        if wState.containsSurface(surfaceID) {
          let existing = wState.surfaces[surfaceID]
          wState.surfaces[surfaceID] = RemoteSurface(
            id: surfaceID,
            title: update.title ?? existing?.title,
            pwd: update.pwd ?? existing?.pwd,
            bellCount: update.bellCount ?? existing?.bellCount ?? 0,
          )
          worktreeStates[wtID] = wState
          break
        }
      }

    case .focusChanged(let worktreeID, let tabID, let surfaceID):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.focusedSurfaceByTab[tabID] = surfaceID
      worktreeStates[worktreeID] = wState

    case .notificationReceived(let worktreeID, let notification):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.notifications.append(notification)
      worktreeStates[worktreeID] = wState

    case .notificationRead(let worktreeID, let notificationID):
      guard var wState = worktreeStates[worktreeID] else { return }
      if let index = wState.notifications.firstIndex(where: { $0.id == notificationID }) {
        let old = wState.notifications[index]
        wState.notifications[index] = RemoteNotification(
          id: old.id,
          surfaceID: old.surfaceID,
          title: old.title,
          body: old.body,
          isRead: true,
        )
      }
      worktreeStates[worktreeID] = wState

    case .notificationsCleared(let worktreeID):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.notifications.removeAll()
      worktreeStates[worktreeID] = wState

    case .taskStatusChanged(let worktreeID, let status):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.taskStatus = status
      worktreeStates[worktreeID] = wState

    case .runScriptStatusChanged(let worktreeID, let isRunning):
      guard var wState = worktreeStates[worktreeID] else { return }
      wState.isRunScriptRunning = isRunning
      worktreeStates[worktreeID] = wState
    }
  }
}

extension RemoteWorktreeState {
  public func containsSurface(_ surfaceID: String) -> Bool {
    splitTrees.values.contains { $0.containsSurface(surfaceID) }
  }
}
