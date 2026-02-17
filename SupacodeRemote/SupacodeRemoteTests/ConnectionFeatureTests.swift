// Created by Barrett Jacobsen

import ComposableArchitecture
import Network
import SupacodeShared
import Testing

@testable import SupacodeRemote

@MainActor
@Suite("ConnectionFeature")
struct ConnectionFeatureTests {

  static let testEndpoint = NWEndpoint.hostPort(
    host: NWEndpoint.Host("192.168.1.10"),
    port: NWEndpoint.Port(rawValue: 7483)!,
  )

  static let testHost = DiscoveredHost(
    id: "test-host",
    name: "Barrett's Mac",
    endpoint: testEndpoint,
  )

  static func makeSnapshot() -> StateSnapshot {
    StateSnapshot(
      repositories: [RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"])],
      selectedWorktreeID: "wt-1",
      worktreeStates: [
        "wt-1": RemoteWorktreeState(
          worktree: RemoteWorktree(id: "wt-1", name: "main", detail: "main", repositoryID: "repo-1"),
          tabs: [],
          selectedTabID: nil,
          splitTrees: [:],
          focusedSurfaceByTab: [:],
          notifications: [],
          taskStatus: .idle,
          isRunScriptRunning: false,
          hasUnseenNotifications: false,
        ),
      ],
    )
  }

  // MARK: - Discovery

  @Test func taskStartsDiscovery() async {
    let store = TestStore(initialState: ConnectionFeature.State()) {
      ConnectionFeature()
    }

    await store.send(.task)
    await store.receive(\.startDiscovery) {
      $0.connectionStatus = .discovering
    }
  }

  @Test func hostsUpdatedSetsDiscoveredHosts() async {
    let store = TestStore(initialState: ConnectionFeature.State()) {
      ConnectionFeature()
    }

    let hosts = [Self.testHost]
    await store.send(.hostsUpdated(hosts)) {
      $0.discoveredHosts = hosts
    }
  }

  // MARK: - Host Selection

  @Test func selectHostWithSavedCredentialsAutoConnects() async {
    var state = ConnectionFeature.State()
    state.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
      pin: "123456",
      sessionToken: "saved-token",
    )
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.selectHost(Self.testHost)) {
      $0.selectedHost = Self.testHost
      $0.pinEntry = "123456"
      $0.connectionStatus = .disconnected
    }
    await store.receive(\.connectWithPIN) {
      $0.connectionStatus = .connecting
    }
    await store.receive(\.connectionResult) {
      $0.connectionStatus = .authenticating
      $0.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
        pin: "123456",
        sessionToken: nil,
      )
    }
  }

  @Test func selectHostWithoutCredentialsShowsPINSheet() async {
    let store = TestStore(initialState: ConnectionFeature.State()) {
      ConnectionFeature()
    }

    await store.send(.selectHost(Self.testHost)) {
      $0.selectedHost = Self.testHost
      $0.pinEntry = ""
      $0.isPINSheetPresented = true
      $0.connectionStatus = .disconnected
    }
  }

  // MARK: - Connection Results

  @Test func connectionSuccessSavesCredentials() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.connectionStatus = .connecting
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let success = ConnectionFeature.ConnectionSuccess(
      hostID: "test-host",
      pin: "123456",
      sessionToken: "new-token",
    )
    await store.send(.connectionResult(.success(success))) {
      $0.connectionStatus = .authenticating
      $0.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
        pin: "123456",
        sessionToken: "new-token",
      )
    }
  }

  @Test func connectionFailureSetsError() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.connectionStatus = .connecting
    state.isPINSheetPresented = true
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let error = RemoteStateError.authFailed("Invalid PIN")
    await store.send(.connectionResult(.failure(error))) {
      $0.connectionStatus = .error("Invalid PIN")
    }
  }

  @Test func connectionFailureFromAutoConnectClearsCredentialsAndShowsPIN() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.connectionStatus = .connecting
    state.isPINSheetPresented = false
    state.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
      pin: "123456",
      sessionToken: "old-token",
    )
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let error = RemoteStateError.authFailed("Invalid session")
    await store.send(.connectionResult(.failure(error))) {
      $0.connectionStatus = .error("Invalid session")
      $0.savedCredentials.removeValue(forKey: "test-host")
      $0.pinEntry = ""
      $0.isPINSheetPresented = true
    }
  }

  // MARK: - Reconnect

  @Test func reconnectUsesSavedCredentials() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
      pin: "123456",
      sessionToken: "saved-token",
    )
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.reconnect) {
      $0.pinEntry = "123456"
      $0.connectionStatus = .connecting
    }
    await store.receive(\.connectWithPIN)
    await store.receive(\.connectionResult) {
      $0.connectionStatus = .authenticating
      $0.savedCredentials["test-host"] = ConnectionFeature.HostCredentials(
        pin: "123456",
        sessionToken: nil,
      )
    }
  }

  @Test func reconnectWithoutSavedCredentialsDoesNothing() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.reconnect)
  }

  @Test func reconnectWithoutHostDoesNothing() async {
    let store = TestStore(initialState: ConnectionFeature.State()) {
      ConnectionFeature()
    }

    await store.send(.reconnect)
  }

  // MARK: - State Updates

  @Test func stateUpdateConnectedDelegates() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.connectionStatus = .authenticating
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let snapshot = Self.makeSnapshot()
    await store.send(.stateUpdate(.connected(snapshot))) {
      $0.connectionStatus = .connected
      $0.isPINSheetPresented = false
    }
    await store.receive(\.delegate.connected)
  }

  @Test func stateUpdateDeltaDelegates() async {
    let store = TestStore(initialState: ConnectionFeature.State()) {
      ConnectionFeature()
    }

    let delta = StateDelta.taskStatusChanged(worktreeID: "wt-1", status: .running)
    await store.send(.stateUpdate(.delta(delta)))
    await store.receive(\.delegate.stateUpdate)
  }

  @Test func stateUpdateDisconnectedSetsError() async {
    var state = ConnectionFeature.State()
    state.connectionStatus = .connected
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.stateUpdate(.disconnected("Connection lost"))) {
      $0.connectionStatus = .error("Connection lost")
    }
  }

  // MARK: - Disconnect

  @Test func disconnectResetsState() async {
    var state = ConnectionFeature.State()
    state.selectedHost = Self.testHost
    state.connectionStatus = .connected
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.disconnect) {
      $0.connectionStatus = .disconnected
      $0.selectedHost = nil
    }
  }

  // MARK: - Manual Host Entry

  @Test func connectToManualHostParsesHostPort() async {
    var state = ConnectionFeature.State()
    state.manualHostEntry = "192.168.1.50:8080"
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let expectedEndpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host("192.168.1.50"),
      port: NWEndpoint.Port(rawValue: 8080)!,
    )
    let expectedHost = DiscoveredHost(
      id: "manual-192.168.1.50:8080",
      name: "192.168.1.50",
      endpoint: expectedEndpoint,
    )

    await store.send(.connectToManualHost) {
      $0.selectedHost = expectedHost
      $0.pinEntry = ""
      $0.isPINSheetPresented = true
      $0.connectionStatus = .disconnected
    }
  }

  @Test func connectToManualHostDefaultPort() async {
    var state = ConnectionFeature.State()
    state.manualHostEntry = "myhost.local"
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    let expectedEndpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host("myhost.local"),
      port: NWEndpoint.Port(rawValue: 7483)!,
    )
    let expectedHost = DiscoveredHost(
      id: "manual-myhost.local:7483",
      name: "myhost.local",
      endpoint: expectedEndpoint,
    )

    await store.send(.connectToManualHost) {
      $0.selectedHost = expectedHost
      $0.pinEntry = ""
      $0.isPINSheetPresented = true
      $0.connectionStatus = .disconnected
    }
  }

  @Test func connectToManualHostEmptyInputDoesNothing() async {
    var state = ConnectionFeature.State()
    state.manualHostEntry = "   "
    let store = TestStore(initialState: state) {
      ConnectionFeature()
    }

    await store.send(.connectToManualHost)
  }
}
