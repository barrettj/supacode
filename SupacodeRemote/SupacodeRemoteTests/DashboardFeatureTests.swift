// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import Testing

@testable import SupacodeRemote

@MainActor
@Suite("DashboardFeature")
struct DashboardFeatureTests {

  static let testWorktree = RemoteWorktree(
    id: "wt-1",
    name: "main",
    detail: "main branch",
    repositoryID: "repo-1",
  )

  static let testWorktree2 = RemoteWorktree(
    id: "wt-2",
    name: "feature",
    detail: "feature/x",
    repositoryID: "repo-1",
  )

  static func makeSnapshot(
    repositories: [RemoteRepository] = [
      RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"]),
    ],
    selectedWorktreeID: String? = "wt-1",
    worktreeStates: [String: RemoteWorktreeState]? = nil,
    expandedRepositoryIDs: Set<String> = []
  ) -> StateSnapshot {
    let states = worktreeStates ?? [
      "wt-1": RemoteWorktreeState(
        worktree: testWorktree,
        tabs: [RemoteTab(id: "tab-1", title: "Terminal", icon: nil, isDirty: false)],
        selectedTabID: "tab-1",
        splitTrees: ["tab-1": RemoteSplitTree(root: .leaf(surfaceID: "surface-1"))],
        focusedSurfaceByTab: ["tab-1": "surface-1"],
        notifications: [],
        taskStatus: .idle,
        isRunScriptRunning: false,
        hasUnseenNotifications: false,
      ),
    ]
    return StateSnapshot(
      repositories: repositories,
      selectedWorktreeID: selectedWorktreeID,
      worktreeStates: states,
      expandedRepositoryIDs: expandedRepositoryIDs,
    )
  }

  @Test func snapshotReceivedSetsRemoteState() async {
    let store = TestStore(initialState: DashboardFeature.State()) {
      DashboardFeature()
    }

    let snapshot = Self.makeSnapshot()
    await store.send(.stateSnapshotReceived(snapshot)) {
      $0.remoteState = RemoteState(snapshot: snapshot)
      $0.selectedWorktreeID = "wt-1"
    }
  }

  @Test func snapshotReceivedAutoSelectsFirstWorktree() async {
    let store = TestStore(initialState: DashboardFeature.State()) {
      DashboardFeature()
    }

    let snapshot = Self.makeSnapshot(selectedWorktreeID: nil)
    await store.send(.stateSnapshotReceived(snapshot)) {
      $0.remoteState = RemoteState(snapshot: snapshot)
      $0.selectedWorktreeID = "wt-1"
    }
  }

  @Test func snapshotReceivedPreservesExistingSelection() async {
    var state = DashboardFeature.State()
    state.selectedWorktreeID = "wt-2"
    let store = TestStore(initialState: state) {
      DashboardFeature()
    }

    let snapshot = Self.makeSnapshot()
    await store.send(.stateSnapshotReceived(snapshot)) {
      $0.remoteState = RemoteState(snapshot: snapshot)
    }
  }

  @Test func snapshotReceivedEmptyReposDoesNotAutoSelect() async {
    let store = TestStore(initialState: DashboardFeature.State()) {
      DashboardFeature()
    }

    let snapshot = Self.makeSnapshot(
      repositories: [],
      selectedWorktreeID: nil,
      worktreeStates: [:],
    )
    await store.send(.stateSnapshotReceived(snapshot)) {
      $0.remoteState = RemoteState(snapshot: snapshot)
    }
  }

  @Test func deltaReceivedAppliesUpdate() async {
    let snapshot = Self.makeSnapshot()
    var state = DashboardFeature.State()
    state.remoteState = RemoteState(snapshot: snapshot)
    let store = TestStore(initialState: state) {
      DashboardFeature()
    }

    let newTab = RemoteTab(id: "tab-2", title: "Terminal 2", icon: nil, isDirty: false)
    await store.send(.stateDeltaReceived(.tabAdded(worktreeID: "wt-1", tab: newTab))) {
      $0.remoteState?.apply(.tabAdded(worktreeID: "wt-1", tab: newTab))
    }
  }

  @Test func selectWorktreeSetsSelectionAndSendsCommand() async {
    let snapshot = Self.makeSnapshot()
    var state = DashboardFeature.State()
    state.remoteState = RemoteState(snapshot: snapshot)
    let store = TestStore(initialState: state) {
      DashboardFeature()
    }

    await store.send(.selectWorktree("wt-2")) {
      $0.selectedWorktreeID = "wt-2"
    }
    await store.receive(\.delegate.sendCommand)
    await store.receive(\.delegate.worktreeSelected)
  }

  @Test func toggleRepositoryExpandedAddsID() async {
    let snapshot = Self.makeSnapshot()
    var state = DashboardFeature.State()
    state.remoteState = RemoteState(snapshot: snapshot)
    let store = TestStore(initialState: state) {
      DashboardFeature()
    }

    await store.send(.toggleRepositoryExpanded("repo-1")) {
      $0.remoteState?.expandedRepositoryIDs.insert("repo-1")
    }
    await store.receive(\.delegate.sendCommand)
  }

  @Test func toggleRepositoryExpandedRemovesID() async {
    let snapshot = Self.makeSnapshot(expandedRepositoryIDs: ["repo-1"])
    var state = DashboardFeature.State()
    state.remoteState = RemoteState(snapshot: snapshot)
    let store = TestStore(initialState: state) {
      DashboardFeature()
    }

    await store.send(.toggleRepositoryExpanded("repo-1")) {
      $0.remoteState?.expandedRepositoryIDs.remove("repo-1")
    }
    await store.receive(\.delegate.sendCommand)
  }
}
