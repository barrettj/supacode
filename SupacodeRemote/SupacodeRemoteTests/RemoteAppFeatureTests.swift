// Created by Barrett Jacobsen

import ComposableArchitecture
import Network
import SupacodeShared
import Testing

@testable import SupacodeRemote

@MainActor
@Suite("RemoteAppFeature")
struct RemoteAppFeatureTests {

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

  static func makeWorktreeState(
    worktree: RemoteWorktree = testWorktree,
    tabs: [RemoteTab] = [RemoteTab(id: "tab-1", title: "Terminal", icon: nil, isDirty: false)],
    selectedTabID: String? = "tab-1",
    surfaces: [String: RemoteSurface] = [
      "surface-1": RemoteSurface(id: "surface-1", title: "zsh", pwd: "/tmp", bellCount: 0),
    ]
  ) -> RemoteWorktreeState {
    RemoteWorktreeState(
      worktree: worktree,
      tabs: tabs,
      selectedTabID: selectedTabID,
      splitTrees: ["tab-1": RemoteSplitTree(root: .leaf(surfaceID: "surface-1"))],
      focusedSurfaceByTab: ["tab-1": "surface-1"],
      notifications: [],
      taskStatus: .idle,
      isRunScriptRunning: false,
      hasUnseenNotifications: false,
      surfaces: surfaces,
    )
  }

  static func makeSnapshot(
    selectedWorktreeID: String? = "wt-1",
    worktreeStates: [String: RemoteWorktreeState]? = nil
  ) -> StateSnapshot {
    let states = worktreeStates ?? ["wt-1": makeWorktreeState()]
    return StateSnapshot(
      repositories: [RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"])],
      selectedWorktreeID: selectedWorktreeID,
      worktreeStates: states,
    )
  }

  // MARK: - Connection Delegates

  @Test func connectedSetsIsConnectedAndForwardsSnapshot() async {
    let store = TestStore(initialState: RemoteAppFeature.State()) {
      RemoteAppFeature()
    }

    let snapshot = Self.makeSnapshot()
    await store.send(.connection(.delegate(.connected(snapshot)))) {
      $0.isConnected = true
      $0.dashboard.isResyncing = false
    }
    await store.receive(\.dashboard.stateSnapshotReceived) {
      $0.dashboard.remoteState = RemoteState(snapshot: snapshot)
      $0.dashboard.selectedWorktreeID = "wt-1"
    }
  }

  @Test func connectedUpdatesExistingTerminalView() async {
    let worktreeState = Self.makeWorktreeState()
    var state = RemoteAppFeature.State()
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    let updatedWorktreeState = Self.makeWorktreeState(
      tabs: [RemoteTab(id: "tab-1", title: "Updated Terminal", icon: nil, isDirty: true)],
    )
    let snapshot = Self.makeSnapshot(worktreeStates: ["wt-1": updatedWorktreeState])

    await store.send(.connection(.delegate(.connected(snapshot)))) {
      $0.isConnected = true
      $0.dashboard.isResyncing = false
      $0.terminalView?.worktreeState = updatedWorktreeState
    }
    await store.receive(\.dashboard.stateSnapshotReceived) {
      $0.dashboard.remoteState = RemoteState(snapshot: snapshot)
      $0.dashboard.selectedWorktreeID = "wt-1"
    }
  }

  // MARK: - Resync Selection Sync

  @Test func resyncConnectedSyncsTerminalToMacSelection() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot(
      selectedWorktreeID: "wt-1",
      worktreeStates: ["wt-1": worktreeState],
    )

    var state = RemoteAppFeature.State()
    state.dashboard.isResyncing = true

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.connection(.delegate(.connected(snapshot)))) {
      $0.isConnected = true
      $0.dashboard.isResyncing = false
      $0.terminalView = TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: worktreeState,
      )
      $0.dashboard.selectedWorktreeID = "wt-1"
    }
    await store.receive(\.dashboard.stateSnapshotReceived) {
      $0.dashboard.remoteState = RemoteState(snapshot: snapshot)
    }
  }

  @Test func resyncConnectedWithNoSelectionClearsTerminal() async {
    let worktreeState = Self.makeWorktreeState()
    var state = RemoteAppFeature.State()
    state.dashboard.isResyncing = true
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    // Empty snapshot with no repos or worktrees
    let snapshot = StateSnapshot(
      repositories: [],
      selectedWorktreeID: nil,
      worktreeStates: [:],
    )
    await store.send(.connection(.delegate(.connected(snapshot)))) {
      $0.isConnected = true
      $0.dashboard.isResyncing = false
      $0.terminalView = nil
    }
    await store.receive(\.dashboard.stateSnapshotReceived) {
      $0.dashboard.remoteState = RemoteState(snapshot: snapshot)
    }
  }

  // MARK: - State Update Deltas

  @Test func deltaSelectedWorktreeChangedSyncsTerminal() async {
    let worktreeState1 = Self.makeWorktreeState()
    let worktreeState2 = Self.makeWorktreeState(worktree: Self.testWorktree2)
    let snapshot = StateSnapshot(
      repositories: [RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1", "wt-2"])],
      selectedWorktreeID: "wt-1",
      worktreeStates: ["wt-1": worktreeState1, "wt-2": worktreeState2],
    )

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.dashboard.selectedWorktreeID = "wt-1"
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState1,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.connection(.delegate(.stateUpdate(.delta(.selectedWorktreeChanged(worktreeID: "wt-2")))))) {
      $0.dashboard.remoteState?.apply(.selectedWorktreeChanged(worktreeID: "wt-2"))
      $0.dashboard.selectedWorktreeID = "wt-2"
      $0.terminalView = TerminalViewFeature.State(
        worktreeID: "wt-2",
        worktreeState: worktreeState2,
      )
    }
  }

  @Test func deltaSelectedWorktreeChangedToNilClearsTerminal() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.dashboard.selectedWorktreeID = "wt-1"
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.connection(.delegate(.stateUpdate(.delta(.selectedWorktreeChanged(worktreeID: nil)))))) {
      $0.dashboard.remoteState?.apply(.selectedWorktreeChanged(worktreeID: nil))
      $0.dashboard.selectedWorktreeID = nil
      $0.terminalView = nil
    }
  }

  @Test func deltaUpdatesTerminalWorktreeState() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    let newTab = RemoteTab(id: "tab-2", title: "Terminal 2", icon: nil, isDirty: false)
    await store.send(.connection(.delegate(.stateUpdate(.delta(.tabAdded(worktreeID: "wt-1", tab: newTab)))))) {
      $0.dashboard.remoteState?.apply(.tabAdded(worktreeID: "wt-1", tab: newTab))
      let updatedState = $0.dashboard.remoteState!.worktreeStates["wt-1"]!
      $0.terminalView?.worktreeState = updatedState
    }
  }

  @Test func terminalContentForwardsToTerminalView() async {
    let worktreeState = Self.makeWorktreeState()
    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
      selectedSurfaceID: "surface-1",
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    let content = TerminalContent(
      surfaceID: "surface-1",
      lines: ["$ ls", "file.txt"],
      cursorRow: 1,
      cursorCol: 0,
      rows: 24,
      cols: 80,
      scrollbackOffset: 0,
    )
    await store.send(.connection(.delegate(.stateUpdate(.terminalContent(content)))))
    await store.receive(\.terminalView.terminalContentReceived) {
      $0.terminalView?.terminalContent = content
    }
  }

  @Test func terminalContentIgnoredWithNoTerminalView() async {
    let store = TestStore(initialState: RemoteAppFeature.State()) {
      RemoteAppFeature()
    }

    let content = TerminalContent(
      surfaceID: "surface-1",
      lines: ["$ ls"],
      cursorRow: 0,
      cursorCol: 0,
      rows: 24,
      cols: 80,
      scrollbackOffset: 0,
    )
    await store.send(.connection(.delegate(.stateUpdate(.terminalContent(content)))))
  }

  // MARK: - Disconnection

  @Test func disconnectedClearsAllState() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.dashboard.selectedWorktreeID = "wt-1"
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.connection(.delegate(.stateUpdate(.disconnected(nil))))) {
      $0.isConnected = false
      $0.terminalView = nil
      $0.dashboard.remoteState = nil
      $0.dashboard.selectedWorktreeID = nil
    }
  }

  // MARK: - Dashboard Delegates

  @Test func dashboardWorktreeSelectedSetsTerminalView() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    var state = RemoteAppFeature.State()
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.dashboard(.delegate(.worktreeSelected("wt-1")))) {
      $0.terminalView = TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: worktreeState,
      )
    }
  }

  // MARK: - Dismiss & Disconnect

  @Test func dismissTerminalClearsTerminalView() async {
    let worktreeState = Self.makeWorktreeState()
    var state = RemoteAppFeature.State()
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.dismissTerminal) {
      $0.terminalView = nil
    }
  }

  @Test func disconnectClearsAllStateAndDisconnectsConnection() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    let testEndpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host("192.168.1.10"),
      port: NWEndpoint.Port(rawValue: 7483)!,
    )
    let testHost = DiscoveredHost(id: "test-host", name: "Mac", endpoint: testEndpoint)

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.connection.connectionStatus = .connected
    state.connection.selectedHost = testHost
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.dashboard.selectedWorktreeID = "wt-1"
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.disconnect) {
      $0.isConnected = false
      $0.terminalView = nil
      $0.dashboard.remoteState = nil
      $0.dashboard.selectedWorktreeID = nil
    }
    await store.receive(\.connection.disconnect) {
      $0.connection.connectionStatus = .disconnected
      $0.connection.selectedHost = nil
    }
  }

  // MARK: - Resync Timeout

  @Test func resyncTimedOutTriggersReconnect() async {
    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.isResyncing = true

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.resyncTimedOut)
    await store.receive(\.connection.reconnect)
  }

  @Test func resyncTimedOutIgnoredWhenNotResyncing() async {
    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.isResyncing = false

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.resyncTimedOut)
  }

  // MARK: - Reconnect Failed

  @Test func reconnectFailedClearsState() async {
    let worktreeState = Self.makeWorktreeState()
    let snapshot = Self.makeSnapshot()

    var state = RemoteAppFeature.State()
    state.isConnected = true
    state.dashboard.isResyncing = true
    state.dashboard.remoteState = RemoteState(snapshot: snapshot)
    state.dashboard.selectedWorktreeID = "wt-1"
    state.terminalView = TerminalViewFeature.State(
      worktreeID: "wt-1",
      worktreeState: worktreeState,
    )

    let store = TestStore(initialState: state) {
      RemoteAppFeature()
    }

    await store.send(.reconnectFailed) {
      $0.dashboard.isResyncing = false
      $0.isConnected = false
      $0.terminalView = nil
      $0.dashboard.remoteState = nil
      $0.dashboard.selectedWorktreeID = nil
    }
  }
}
