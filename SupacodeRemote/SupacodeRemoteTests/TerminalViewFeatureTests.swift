// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import Testing

@testable import SupacodeRemote

@MainActor
@Suite("TerminalViewFeature")
struct TerminalViewFeatureTests {
  static let testWorktree = RemoteWorktree(id: "wt-1", name: "main", detail: "/path/to/repo", repositoryID: "repo-1")

  static let testTab1 = RemoteTab(id: "tab-1", title: "Tab 1", icon: nil, isDirty: false)
  static let testTab2 = RemoteTab(id: "tab-2", title: "Tab 2", icon: nil, isDirty: false)

  static func makeWorktreeState(
    tabs: [RemoteTab] = [testTab1, testTab2],
    selectedTabID: String? = "tab-1",
    splitTrees: [String: RemoteSplitTree] = [
      "tab-1": RemoteSplitTree(root: .leaf(surfaceID: "surface-1")),
    ],
    focusedSurfaceByTab: [String: String] = ["tab-1": "surface-1"],
    surfaces: [String: RemoteSurface] = [
      "surface-1": RemoteSurface(id: "surface-1", title: "zsh", pwd: "/home", bellCount: 0),
    ]
  ) -> RemoteWorktreeState {
    RemoteWorktreeState(
      worktree: testWorktree,
      tabs: tabs,
      selectedTabID: selectedTabID,
      splitTrees: splitTrees,
      focusedSurfaceByTab: focusedSurfaceByTab,
      notifications: [],
      taskStatus: .idle,
      isRunScriptRunning: false,
      hasUnseenNotifications: false,
      surfaces: surfaces,
    )
  }

  @Test func tabSelectionDelegatesCommand() async {
    let store = TestStore(
      initialState: TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: Self.makeWorktreeState(),
        selectedSurfaceID: "surface-1",
      )
    ) {
      TerminalViewFeature()
    }

    await store.send(.selectTab("tab-2")) {
      $0.terminalContent = nil
      $0.selectedSurfaceID = nil
    }
    await store.receive(\.delegate.requestTerminalContent)
    await store.receive(\.delegate.sendCommand)
  }

  @Test func surfaceSelectionStartsStreaming() async {
    let store = TestStore(
      initialState: TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: Self.makeWorktreeState(),
        selectedSurfaceID: nil,
      )
    ) {
      TerminalViewFeature()
    }

    await store.send(.selectSurface("surface-1")) {
      $0.selectedSurfaceID = "surface-1"
      $0.terminalContent = nil
    }
    await store.receive(\.delegate.sendCommand)
    await store.receive(\.delegate.requestTerminalContent)
  }

  @Test func sendInputClearsTextAndDelegates() async {
    let store = TestStore(
      initialState: TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: Self.makeWorktreeState(),
        selectedSurfaceID: "surface-1",
        inputText: "ls -la",
      )
    ) {
      TerminalViewFeature()
    }

    await store.send(.sendInput) {
      $0.inputText = ""
    }
    await store.receive(\.delegate.sendCommand)
  }

  @Test func sendKeyDelegatesCommand() async {
    let keyEvent = RemoteKeyEvent(
      key: .enter,
      modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0),
      characterValue: nil,
    )
    let store = TestStore(
      initialState: TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: Self.makeWorktreeState(),
        selectedSurfaceID: "surface-1",
      )
    ) {
      TerminalViewFeature()
    }

    await store.send(.sendKey(keyEvent))
    await store.receive(\.delegate.sendCommand)
  }

  @Test func switchInputModeUpdatesState() async {
    let store = TestStore(
      initialState: TerminalViewFeature.State(
        worktreeID: "wt-1",
        worktreeState: Self.makeWorktreeState(),
      )
    ) {
      TerminalViewFeature()
    }

    await store.send(.switchInputMode(.keyboard)) {
      $0.inputMode = .keyboard
    }
  }
}
