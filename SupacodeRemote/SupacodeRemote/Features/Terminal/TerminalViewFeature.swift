// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared

@Reducer
struct TerminalViewFeature {
  @ObservableState
  struct State: Equatable {
    let worktreeID: String
    var worktreeState: RemoteWorktreeState
    var selectedSurfaceID: String?
    var terminalContent: TerminalContent?
    var inputText: String = ""
    var inputMode: InputMode = .quickShortcuts
    var isAtBottom = true

    enum InputMode: String, Equatable, CaseIterable {
      case voice
      case keyboard
      case terminalKeyboard
      case quickShortcuts
    }

    // Derived helpers
    var currentTabID: String? { worktreeState.selectedTabID }
    var currentSplitTree: RemoteSplitTree? {
      guard let tabID = currentTabID else { return nil }
      return worktreeState.splitTrees[tabID]
    }
    var focusedSurfaceIDForCurrentTab: String? {
      guard let tabID = currentTabID else { return nil }
      return worktreeState.focusedSurfaceByTab[tabID]
    }
  }

  enum Action: BindableAction {
    case task
    case selectTab(String)
    case selectSurface(String)
    case terminalContentReceived(TerminalContent)
    case sendInput
    case sendInputWithoutNewline
    case sendKey(RemoteKeyEvent)
    case createTab
    case closeTab(String)
    case splitHorizontal
    case splitVertical
    case closeSurface
    case switchInputMode(State.InputMode)
    case delegate(Delegate)
    case binding(BindingAction<State>)
  }

  @CasePathable
  enum Delegate: Equatable {
    case sendCommand(RemoteCommand)
    case requestTerminalContent(String, TerminalContentRequest.ContentAction)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .task:
        // Start streaming for the currently focused surface
        if let surfaceID = state.selectedSurfaceID ?? state.focusedSurfaceIDForCurrentTab {
          state.selectedSurfaceID = surfaceID
          return .send(.delegate(.requestTerminalContent(surfaceID, .startStreaming)))
        }
        return .none

      case .selectTab(let tabID):
        // Stop old streaming, select tab, start new streaming
        var effects: [Effect<Action>] = []
        if let oldSurface = state.selectedSurfaceID {
          effects.append(.send(.delegate(.requestTerminalContent(oldSurface, .stopStreaming))))
        }
        effects.append(.send(.delegate(.sendCommand(.selectTab(worktreeID: state.worktreeID, tabID: tabID)))))
        state.terminalContent = nil
        // New surface will be determined when state updates come in
        if let surfaceID = state.worktreeState.focusedSurfaceByTab[tabID] {
          state.selectedSurfaceID = surfaceID
          effects.append(.send(.delegate(.requestTerminalContent(surfaceID, .startStreaming))))
        } else {
          state.selectedSurfaceID = nil
        }
        return .merge(effects)

      case .selectSurface(let surfaceID):
        var effects: [Effect<Action>] = []
        if let oldSurface = state.selectedSurfaceID, oldSurface != surfaceID {
          effects.append(.send(.delegate(.requestTerminalContent(oldSurface, .stopStreaming))))
        }
        state.selectedSurfaceID = surfaceID
        state.terminalContent = nil
        if let tabID = state.currentTabID {
          effects.append(
            .send(
              .delegate(.sendCommand(.focusSurface(worktreeID: state.worktreeID, tabID: tabID, surfaceID: surfaceID)))
            )
          )
        }
        effects.append(.send(.delegate(.requestTerminalContent(surfaceID, .startStreaming))))
        return .merge(effects)

      case .terminalContentReceived(let content):
        if content.surfaceID == state.selectedSurfaceID {
          state.terminalContent = content
        }
        return .none

      case .sendInput:
        guard !state.inputText.isEmpty, let surfaceID = state.selectedSurfaceID else { return .none }
        let text = state.inputText
        state.inputText = ""
        return .send(.delegate(.sendCommand(.sendInput(surfaceID: surfaceID, text: text, appendNewline: true))))

      case .sendInputWithoutNewline:
        guard !state.inputText.isEmpty, let surfaceID = state.selectedSurfaceID else { return .none }
        let text = state.inputText
        state.inputText = ""
        return .send(.delegate(.sendCommand(.sendInput(surfaceID: surfaceID, text: text, appendNewline: false))))

      case .sendKey(let keyEvent):
        guard let surfaceID = state.selectedSurfaceID else { return .none }
        return .send(.delegate(.sendCommand(.sendKey(surfaceID: surfaceID, key: keyEvent))))

      case .createTab:
        return .send(.delegate(.sendCommand(.createTab(worktreeID: state.worktreeID))))

      case .closeTab(let tabID):
        return .send(.delegate(.sendCommand(.closeTab(worktreeID: state.worktreeID, tabID: tabID))))

      case .splitHorizontal:
        guard let tabID = state.currentTabID, let surfaceID = state.selectedSurfaceID else { return .none }
        return .send(
          .delegate(.sendCommand(.splitHorizontal(worktreeID: state.worktreeID, tabID: tabID, surfaceID: surfaceID)))
        )

      case .splitVertical:
        guard let tabID = state.currentTabID, let surfaceID = state.selectedSurfaceID else { return .none }
        return .send(
          .delegate(.sendCommand(.splitVertical(worktreeID: state.worktreeID, tabID: tabID, surfaceID: surfaceID)))
        )

      case .closeSurface:
        guard let tabID = state.currentTabID, let surfaceID = state.selectedSurfaceID else { return .none }
        return .send(
          .delegate(.sendCommand(.closeSurface(worktreeID: state.worktreeID, tabID: tabID, surfaceID: surfaceID)))
        )

      case .switchInputMode(let mode):
        state.inputMode = mode
        return .none

      case .delegate, .binding:
        return .none
      }
    }
  }
}
