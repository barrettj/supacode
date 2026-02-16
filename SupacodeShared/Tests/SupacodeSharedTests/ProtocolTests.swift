// Created by Barrett Jacobsen

import Foundation
import Testing

@testable import SupacodeShared

@Suite("Protocol Message Types")
struct ProtocolTests {

  private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(value)
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func roundTripMessage(_ message: RemoteMessage) throws -> RemoteMessage {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(message)
    return try JSONDecoder().decode(RemoteMessage.self, from: data)
  }

  // MARK: - RemoteMessage Envelope

  @Test func messageEnvelopeWithPayload() throws {
    let challenge = AuthChallenge(nonce: "abc123")
    let message = try RemoteMessage(type: .authChallenge, payload: challenge)
    let decoded = try roundTripMessage(message)
    #expect(decoded.version == 1)
    #expect(decoded.type == .authChallenge)
    let decodedChallenge = try decoded.decode(AuthChallenge.self)
    #expect(decodedChallenge == challenge)
  }

  @Test func messageEnvelopeWithoutPayload() throws {
    let id = UUID()
    let message = RemoteMessage(type: .ping, id: id)
    let decoded = try roundTripMessage(message)
    #expect(decoded.version == 1)
    #expect(decoded.type == .ping)
    #expect(decoded.id == id)
    #expect(decoded.payload == Data())
  }

  @Test func messageEnvelopeCommand() throws {
    let command = RemoteCommand.createTab(worktreeID: "wt-1")
    let message = try RemoteMessage(type: .command, payload: command)
    let decoded = try roundTripMessage(message)
    #expect(decoded.type == .command)
    let decodedCommand = try decoded.decode(RemoteCommand.self)
    #expect(decodedCommand == command)
  }

  @Test func messageEnvelopeTerminalContent() throws {
    let content = TerminalContent(
      surfaceID: "s-1",
      lines: ["hello", "world"],
      cursorRow: 1,
      cursorCol: 5,
      rows: 24,
      cols: 80,
      scrollbackOffset: 0
    )
    let message = try RemoteMessage(type: .terminalContent, payload: content)
    let decoded = try roundTripMessage(message)
    let decodedContent = try decoded.decode(TerminalContent.self)
    #expect(decodedContent == content)
  }

  // MARK: - Auth Messages

  @Test func authChallengeRoundTrip() throws {
    let challenge = AuthChallenge(nonce: "test-nonce-456")
    let decoded = try roundTrip(challenge)
    #expect(decoded == challenge)
  }

  @Test func authRequestRoundTrip() throws {
    let request = AuthRequest(
      hash: "sha256-hash-value",
      deviceName: "Barrett's iPhone",
      sessionToken: "existing-token"
    )
    let decoded = try roundTrip(request)
    #expect(decoded == request)
  }

  @Test func authRequestNilToken() throws {
    let request = AuthRequest(
      hash: "sha256-hash-value",
      deviceName: "Barrett's iPhone",
      sessionToken: nil
    )
    let decoded = try roundTrip(request)
    #expect(decoded == request)
    #expect(decoded.sessionToken == nil)
  }

  @Test func authResponseSuccess() throws {
    let response = AuthResponse(
      success: true,
      sessionToken: "new-session-token",
      error: nil
    )
    let decoded = try roundTrip(response)
    #expect(decoded == response)
    #expect(decoded.success == true)
  }

  @Test func authResponseFailure() throws {
    let response = AuthResponse(
      success: false,
      sessionToken: nil,
      error: "Invalid credentials"
    )
    let decoded = try roundTrip(response)
    #expect(decoded == response)
    #expect(decoded.success == false)
    #expect(decoded.error == "Invalid credentials")
  }

  // MARK: - StateSnapshot

  @Test func stateSnapshotRoundTrip() throws {
    let worktree = RemoteWorktree(
      id: "wt-1",
      name: "main",
      detail: "main branch",
      repositoryID: "repo-1"
    )
    let tab = RemoteTab(id: "tab-1", title: "Terminal", icon: nil, isDirty: false)
    let notification = RemoteNotification(
      id: "n-1",
      surfaceID: "s-1",
      title: "Done",
      body: "Task complete",
      isRead: false
    )
    let worktreeState = RemoteWorktreeState(
      worktree: worktree,
      tabs: [tab],
      selectedTabID: "tab-1",
      splitTrees: ["tab-1": RemoteSplitTree(root: .leaf(surfaceID: "s-1"))],
      focusedSurfaceByTab: ["tab-1": "s-1"],
      notifications: [notification],
      taskStatus: .running,
      isRunScriptRunning: false,
      hasUnseenNotifications: true
    )
    let snapshot = StateSnapshot(
      repositories: [RemoteRepository(id: "repo-1", name: "my-project", worktreeIDs: ["wt-1"])],
      selectedWorktreeID: "wt-1",
      worktreeStates: ["wt-1": worktreeState]
    )
    let decoded = try roundTrip(snapshot)
    #expect(decoded == snapshot)
    #expect(decoded.worktreeStates["wt-1"]?.tabs.count == 1)
    #expect(decoded.worktreeStates["wt-1"]?.hasUnseenNotifications == true)
  }

  @Test func stateSnapshotEmpty() throws {
    let snapshot = StateSnapshot(
      repositories: [],
      selectedWorktreeID: nil,
      worktreeStates: [:]
    )
    let decoded = try roundTrip(snapshot)
    #expect(decoded == snapshot)
  }

  // MARK: - StateDelta

  @Test func stateDeltaWorktreeAdded() throws {
    let worktreeState = RemoteWorktreeState(
      worktree: RemoteWorktree(id: "wt-2", name: "feature", detail: "feature/x", repositoryID: "repo-1"),
      tabs: [],
      selectedTabID: nil,
      splitTrees: [:],
      focusedSurfaceByTab: [:],
      notifications: [],
      taskStatus: .idle,
      isRunScriptRunning: false,
      hasUnseenNotifications: false
    )
    let delta = StateDelta.worktreeAdded(worktreeState)
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaWorktreeRemoved() throws {
    let delta = StateDelta.worktreeRemoved(worktreeID: "wt-3")
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaTabRemoved() throws {
    let delta = StateDelta.tabRemoved(worktreeID: "wt-1", tabID: "tab-2")
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaFocusChanged() throws {
    let delta = StateDelta.focusChanged(worktreeID: "wt-1", tabID: "tab-1", surfaceID: "s-2")
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaTaskStatusChanged() throws {
    let delta = StateDelta.taskStatusChanged(worktreeID: "wt-1", status: .running)
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaTabUpdated() throws {
    let update = RemoteTabUpdate(title: "New Title", isDirty: true)
    let delta = StateDelta.tabUpdated(worktreeID: "wt-1", tabID: "tab-1", update: update)
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaSurfaceMetadataUpdated() throws {
    let update = RemoteSurfaceUpdate(title: "zsh", pwd: "/tmp", bellCount: 1)
    let delta = StateDelta.surfaceMetadataUpdated(surfaceID: "s-1", update: update)
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  @Test func stateDeltaRepositoriesChanged() throws {
    let repos = [
      RemoteRepository(id: "r-1", name: "proj-a", worktreeIDs: ["wt-1"]),
      RemoteRepository(id: "r-2", name: "proj-b", worktreeIDs: ["wt-2", "wt-3"]),
    ]
    let delta = StateDelta.repositoriesChanged(repos)
    let decoded = try roundTrip(delta)
    #expect(decoded == delta)
  }

  // MARK: - RemoteCommand

  @Test func commandSelectWorktree() throws {
    let command = RemoteCommand.selectWorktree(worktreeID: "wt-1")
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandSendInput() throws {
    let command = RemoteCommand.sendInput(surfaceID: "s-1", text: "ls -la", appendNewline: true)
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandSendKey() throws {
    let keyEvent = RemoteKeyEvent(
      key: .character,
      modifiers: [.ctrl, .shift],
      characterValue: "c"
    )
    let command = RemoteCommand.sendKey(surfaceID: "s-1", key: keyEvent)
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandSplitHorizontal() throws {
    let command = RemoteCommand.splitHorizontal(worktreeID: "wt-1", tabID: "tab-1", surfaceID: "s-1")
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandCloseTab() throws {
    let command = RemoteCommand.closeTab(worktreeID: "wt-1", tabID: "tab-1")
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandRunScript() throws {
    let command = RemoteCommand.runScript(worktreeID: "wt-1", script: "npm test")
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  @Test func commandSelectNextWorktree() throws {
    let command = RemoteCommand.selectNextWorktree
    let decoded = try roundTrip(command)
    #expect(decoded == command)
  }

  // MARK: - TerminalContent

  @Test func terminalContentRoundTrip() throws {
    let content = TerminalContent(
      surfaceID: "s-1",
      lines: ["$ ls", "file1.txt", "file2.txt"],
      cursorRow: 3,
      cursorCol: 2,
      rows: 24,
      cols: 80,
      scrollbackOffset: 100
    )
    let decoded = try roundTrip(content)
    #expect(decoded == content)
    #expect(decoded.lines.count == 3)
  }

  @Test func terminalContentNilCursor() throws {
    let content = TerminalContent(
      surfaceID: "s-2",
      lines: [],
      cursorRow: nil,
      cursorCol: nil,
      rows: 24,
      cols: 80,
      scrollbackOffset: 0
    )
    let decoded = try roundTrip(content)
    #expect(decoded == content)
    #expect(decoded.cursorRow == nil)
  }

  @Test func terminalContentRequestRoundTrip() throws {
    let request = TerminalContentRequest(surfaceID: "s-1", action: .startStreaming)
    let decoded = try roundTrip(request)
    #expect(decoded == request)
  }

  // MARK: - RemoteKeyEvent

  @Test func keyEventSimpleKey() throws {
    let event = RemoteKeyEvent(key: .enter, modifiers: [], characterValue: nil)
    let decoded = try roundTrip(event)
    #expect(decoded == event)
    #expect(decoded.key == .enter)
    #expect(decoded.modifiers.isEmpty)
  }

  @Test func keyEventWithModifiers() throws {
    let event = RemoteKeyEvent(
      key: .character,
      modifiers: [.ctrl, .alt, .shift],
      characterValue: "z"
    )
    let decoded = try roundTrip(event)
    #expect(decoded == event)
    #expect(decoded.modifiers.contains(.ctrl))
    #expect(decoded.modifiers.contains(.alt))
    #expect(decoded.modifiers.contains(.shift))
    #expect(!decoded.modifiers.contains(.superKey))
    #expect(decoded.characterValue == "z")
  }

  @Test func keyEventFunctionKey() throws {
    let event = RemoteKeyEvent(key: .f5, modifiers: [.superKey], characterValue: nil)
    let decoded = try roundTrip(event)
    #expect(decoded == event)
  }

  @Test func keyEventArrowKey() throws {
    let event = RemoteKeyEvent(key: .arrowUp, modifiers: [.shift], characterValue: nil)
    let decoded = try roundTrip(event)
    #expect(decoded == event)
  }
}
