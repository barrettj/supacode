// Created by Barrett Jacobsen

import Testing

@testable import SupacodeShared

@Suite("State Delta Application")
struct StateDeltaApplicationTests {

  private func makeBaseState() -> RemoteState {
    let snapshot = StateSnapshot(
      repositories: [RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"])],
      selectedWorktreeID: "wt-1",
      worktreeStates: [
        "wt-1": RemoteWorktreeState(
          worktree: RemoteWorktree(id: "wt-1", name: "main", detail: "main", repositoryID: "repo-1"),
          tabs: [RemoteTab(id: "tab-1", title: "Terminal 1", icon: "terminal", isDirty: false)],
          selectedTabID: "tab-1",
          splitTrees: [
            "tab-1": RemoteSplitTree(root: .leaf(surfaceID: "surface-1")),
          ],
          focusedSurfaceByTab: ["tab-1": "surface-1"],
          notifications: [],
          taskStatus: .idle,
          isRunScriptRunning: false,
          hasUnseenNotifications: false,
          surfaces: ["surface-1": RemoteSurface(id: "surface-1", title: "zsh", pwd: "/tmp", bellCount: 0)],
        ),
      ]
    )
    return RemoteState(snapshot: snapshot)
  }

  @Test func repositoriesChanged() {
    var state = makeBaseState()
    let newRepos = [
      RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"]),
      RemoteRepository(id: "repo-2", name: "other-project", worktreeIDs: ["wt-2"]),
    ]
    state.apply(.repositoriesChanged(newRepos))
    #expect(state.repositories.count == 2)
    #expect(state.repositories[1].name == "other-project")
  }

  @Test func worktreeAdded() {
    var state = makeBaseState()
    let newWorktreeState = RemoteWorktreeState(
      worktree: RemoteWorktree(id: "wt-2", name: "feature", detail: "feature/x", repositoryID: "repo-1"),
      tabs: [RemoteTab(id: "tab-2", title: "Terminal 2", icon: nil, isDirty: false)],
      selectedTabID: "tab-2",
      splitTrees: ["tab-2": RemoteSplitTree(root: .leaf(surfaceID: "surface-2"))],
      focusedSurfaceByTab: ["tab-2": "surface-2"],
      notifications: [],
      taskStatus: .idle,
      isRunScriptRunning: false,
      hasUnseenNotifications: false,
    )
    state.apply(.worktreeAdded(newWorktreeState))
    #expect(state.worktreeStates.count == 2)
    #expect(state.worktreeStates["wt-2"]?.worktree.name == "feature")
  }

  @Test func worktreeRemoved() {
    var state = makeBaseState()
    state.apply(.worktreeRemoved(worktreeID: "wt-1"))
    #expect(state.worktreeStates.isEmpty)
  }

  @Test func worktreeRemovedNonexistent() {
    var state = makeBaseState()
    state.apply(.worktreeRemoved(worktreeID: "wt-nonexistent"))
    #expect(state.worktreeStates.count == 1)
  }

  @Test func selectedWorktreeChanged() {
    var state = makeBaseState()
    state.apply(.selectedWorktreeChanged(worktreeID: "wt-2"))
    #expect(state.selectedWorktreeID == "wt-2")
  }

  @Test func selectedWorktreeChangedToNil() {
    var state = makeBaseState()
    state.apply(.selectedWorktreeChanged(worktreeID: nil))
    #expect(state.selectedWorktreeID == nil)
  }

  @Test func tabAdded() {
    var state = makeBaseState()
    let newTab = RemoteTab(id: "tab-2", title: "Terminal 2", icon: "terminal", isDirty: false)
    state.apply(.tabAdded(worktreeID: "wt-1", tab: newTab))
    #expect(state.worktreeStates["wt-1"]?.tabs.count == 2)
    #expect(state.worktreeStates["wt-1"]?.tabs[1].id == "tab-2")
  }

  @Test func tabAddedToNonexistentWorktree() {
    var state = makeBaseState()
    let newTab = RemoteTab(id: "tab-2", title: "Terminal 2", icon: nil, isDirty: false)
    state.apply(.tabAdded(worktreeID: "wt-nonexistent", tab: newTab))
    #expect(state.worktreeStates["wt-1"]?.tabs.count == 1)
  }

  @Test func tabRemoved() {
    var state = makeBaseState()
    state.apply(.tabRemoved(worktreeID: "wt-1", tabID: "tab-1"))
    #expect(state.worktreeStates["wt-1"]?.tabs.isEmpty == true)
  }

  @Test func tabRemovedNonexistent() {
    var state = makeBaseState()
    state.apply(.tabRemoved(worktreeID: "wt-1", tabID: "tab-nonexistent"))
    #expect(state.worktreeStates["wt-1"]?.tabs.count == 1)
  }

  @Test func tabUpdatedTitle() {
    var state = makeBaseState()
    let update = RemoteTabUpdate(title: "New Title")
    state.apply(.tabUpdated(worktreeID: "wt-1", tabID: "tab-1", update: update))
    let tab = state.worktreeStates["wt-1"]?.tabs.first
    #expect(tab?.title == "New Title")
    #expect(tab?.icon == "terminal")
    #expect(tab?.isDirty == false)
  }

  @Test func tabUpdatedAllFields() {
    var state = makeBaseState()
    let update = RemoteTabUpdate(title: "Updated", icon: "star", isDirty: true)
    state.apply(.tabUpdated(worktreeID: "wt-1", tabID: "tab-1", update: update))
    let tab = state.worktreeStates["wt-1"]?.tabs.first
    #expect(tab?.title == "Updated")
    #expect(tab?.icon == "star")
    #expect(tab?.isDirty == true)
  }

  @Test func tabUpdatedNonexistentTab() {
    var state = makeBaseState()
    let update = RemoteTabUpdate(title: "New Title")
    state.apply(.tabUpdated(worktreeID: "wt-1", tabID: "tab-nonexistent", update: update))
    #expect(state.worktreeStates["wt-1"]?.tabs.first?.title == "Terminal 1")
  }

  @Test func selectedTabChanged() {
    var state = makeBaseState()
    state.apply(.selectedTabChanged(worktreeID: "wt-1", tabID: "tab-2"))
    #expect(state.worktreeStates["wt-1"]?.selectedTabID == "tab-2")
  }

  @Test func selectedTabChangedToNil() {
    var state = makeBaseState()
    state.apply(.selectedTabChanged(worktreeID: "wt-1", tabID: nil))
    #expect(state.worktreeStates["wt-1"]?.selectedTabID == nil)
  }

  @Test func splitTreeChanged() {
    var state = makeBaseState()
    let newTree = RemoteSplitTree(
      root: .split(
        RemoteSplitTree.Split(
          direction: .horizontal,
          ratio: 0.5,
          left: .leaf(surfaceID: "surface-1"),
          right: .leaf(surfaceID: "surface-2")
        )
      )
    )
    state.apply(.splitTreeChanged(worktreeID: "wt-1", tabID: "tab-1", tree: newTree))
    #expect(state.worktreeStates["wt-1"]?.splitTrees["tab-1"] == newTree)
  }

  @Test func surfaceMetadataUpdated() {
    var state = makeBaseState()
    let update = RemoteSurfaceUpdate(title: "bash", pwd: "/home", bellCount: 2)
    state.apply(.surfaceMetadataUpdated(surfaceID: "surface-1", update: update))
    let surface = state.worktreeStates["wt-1"]?.surfaces["surface-1"]
    #expect(surface?.title == "bash")
    #expect(surface?.pwd == "/home")
    #expect(surface?.bellCount == 2)
  }

  @Test func surfaceMetadataUpdatedPartial() {
    var state = makeBaseState()
    let update = RemoteSurfaceUpdate(title: "bash")
    state.apply(.surfaceMetadataUpdated(surfaceID: "surface-1", update: update))
    let surface = state.worktreeStates["wt-1"]?.surfaces["surface-1"]
    #expect(surface?.title == "bash")
    #expect(surface?.pwd == "/tmp")
    #expect(surface?.bellCount == 0)
  }

  @Test func surfaceMetadataUpdatedNonexistent() {
    var state = makeBaseState()
    let update = RemoteSurfaceUpdate(title: "bash")
    state.apply(.surfaceMetadataUpdated(surfaceID: "surface-nonexistent", update: update))
    // Should be a no-op since the surface doesn't exist in any split tree
    #expect(state.worktreeStates["wt-1"]?.surfaces["surface-nonexistent"] == nil)
  }

  @Test func focusChanged() {
    var state = makeBaseState()
    state.apply(.focusChanged(worktreeID: "wt-1", tabID: "tab-1", surfaceID: "surface-2"))
    #expect(state.worktreeStates["wt-1"]?.focusedSurfaceByTab["tab-1"] == "surface-2")
  }

  @Test func notificationReceived() {
    var state = makeBaseState()
    let notification = RemoteNotification(
      id: "notif-1",
      surfaceID: "surface-1",
      title: "Build Done",
      body: "Build succeeded",
      isRead: false,
    )
    state.apply(.notificationReceived(worktreeID: "wt-1", notification: notification))
    #expect(state.worktreeStates["wt-1"]?.notifications.count == 1)
    #expect(state.worktreeStates["wt-1"]?.notifications.first?.id == "notif-1")
  }

  @Test func notificationRead() {
    var state = makeBaseState()
    let notification = RemoteNotification(
      id: "notif-1",
      surfaceID: "surface-1",
      title: "Build Done",
      body: "Build succeeded",
      isRead: false,
    )
    state.apply(.notificationReceived(worktreeID: "wt-1", notification: notification))
    state.apply(.notificationRead(worktreeID: "wt-1", notificationID: "notif-1"))
    #expect(state.worktreeStates["wt-1"]?.notifications.first?.isRead == true)
  }

  @Test func notificationReadNonexistent() {
    var state = makeBaseState()
    state.apply(.notificationRead(worktreeID: "wt-1", notificationID: "notif-nonexistent"))
    #expect(state.worktreeStates["wt-1"]?.notifications.isEmpty == true)
  }

  @Test func notificationsCleared() {
    var state = makeBaseState()
    let notification = RemoteNotification(
      id: "notif-1",
      surfaceID: "surface-1",
      title: "Build Done",
      body: "Build succeeded",
      isRead: false,
    )
    state.apply(.notificationReceived(worktreeID: "wt-1", notification: notification))
    state.apply(.notificationsCleared(worktreeID: "wt-1"))
    #expect(state.worktreeStates["wt-1"]?.notifications.isEmpty == true)
  }

  @Test func taskStatusChanged() {
    var state = makeBaseState()
    state.apply(.taskStatusChanged(worktreeID: "wt-1", status: .running))
    #expect(state.worktreeStates["wt-1"]?.taskStatus == .running)
  }

  @Test func runScriptStatusChanged() {
    var state = makeBaseState()
    state.apply(.runScriptStatusChanged(worktreeID: "wt-1", isRunning: true))
    #expect(state.worktreeStates["wt-1"]?.isRunScriptRunning == true)
  }

  @Test func runScriptStatusChangedToFalse() {
    var state = makeBaseState()
    state.apply(.runScriptStatusChanged(worktreeID: "wt-1", isRunning: true))
    state.apply(.runScriptStatusChanged(worktreeID: "wt-1", isRunning: false))
    #expect(state.worktreeStates["wt-1"]?.isRunScriptRunning == false)
  }

  @Test func repositoryExpandedChanged() {
    var state = makeBaseState()
    state.expandedRepositoryIDs = Set(state.repositories.map(\.id))
    state.apply(.repositoryExpandedChanged(repositoryID: "repo-1", isExpanded: false))
    #expect(!state.expandedRepositoryIDs.contains("repo-1"))
    state.apply(.repositoryExpandedChanged(repositoryID: "repo-1", isExpanded: true))
    #expect(state.expandedRepositoryIDs.contains("repo-1"))
  }

  @Test func multipleDeltas() {
    var state = makeBaseState()
    let newTab = RemoteTab(id: "tab-2", title: "Terminal 2", icon: nil, isDirty: false)
    state.apply(.tabAdded(worktreeID: "wt-1", tab: newTab))
    state.apply(.selectedTabChanged(worktreeID: "wt-1", tabID: "tab-2"))
    state.apply(.taskStatusChanged(worktreeID: "wt-1", status: .running))
    #expect(state.worktreeStates["wt-1"]?.tabs.count == 2)
    #expect(state.worktreeStates["wt-1"]?.selectedTabID == "tab-2")
    #expect(state.worktreeStates["wt-1"]?.taskStatus == .running)
  }
}
