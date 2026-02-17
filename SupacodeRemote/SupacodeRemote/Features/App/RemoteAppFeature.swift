// Created by Barrett Jacobsen

import ComposableArchitecture
import OSLog
import SupacodeShared

private let logger = Logger(subsystem: "com.supacode.remote", category: "RemoteApp")

@Reducer
struct RemoteAppFeature {
  @ObservableState
  struct State: Equatable {
    var connection = ConnectionFeature.State()
    var dashboard = DashboardFeature.State()
    var terminalView: TerminalViewFeature.State?
    var isConnected = false
  }

  enum Action {
    case appLaunched
    case appBecameActive
    case connection(ConnectionFeature.Action)
    case dashboard(DashboardFeature.Action)
    case terminalView(TerminalViewFeature.Action)
    case dismissTerminal
    case disconnect
  }

  @Dependency(\.remoteStateClient) var remoteStateClient

  var body: some Reducer<State, Action> {
    Scope(state: \.connection, action: \.connection) {
      ConnectionFeature()
    }
    Scope(state: \.dashboard, action: \.dashboard) {
      DashboardFeature()
    }

    Reduce { state, action in
      switch action {
      case .appLaunched:
        return .none

      case .appBecameActive:
        if state.isConnected {
          state.dashboard.isResyncing = true
        }
        return .none

      // MARK: - Connection delegates
      case .connection(.delegate(.connected(let snapshot))):
        state.isConnected = true
        state.dashboard.isResyncing = false
        if let terminalView = state.terminalView,
          let updatedState = snapshot.worktreeStates[terminalView.worktreeID]
        {
          state.terminalView?.worktreeState = updatedState
        }
        return .send(.dashboard(.stateSnapshotReceived(snapshot)))

      case .connection(.delegate(.stateUpdate(let update))):
        switch update {
        case .connected(let snapshot):
          state.dashboard.isResyncing = false
          if let terminalView = state.terminalView,
            let updatedState = snapshot.worktreeStates[terminalView.worktreeID]
          {
            state.terminalView?.worktreeState = updatedState
          }
          return .send(.dashboard(.stateSnapshotReceived(snapshot)))

        case .delta(let delta):
          state.dashboard.remoteState?.apply(delta)
          // Sync selection from mac
          if case .selectedWorktreeChanged(let worktreeID) = delta {
            state.dashboard.selectedWorktreeID = worktreeID
            if let worktreeID,
              let worktreeState = state.dashboard.remoteState?.worktreeStates[worktreeID]
            {
              state.terminalView = TerminalViewFeature.State(
                worktreeID: worktreeID,
                worktreeState: worktreeState,
              )
            } else {
              state.terminalView = nil
            }
          }
          if let terminalView = state.terminalView,
            let updatedState = state.dashboard.remoteState?.worktreeStates[terminalView.worktreeID]
          {
            state.terminalView?.worktreeState = updatedState
          }
          return .none

        case .terminalContent(let content):
          if state.terminalView != nil {
            return .send(.terminalView(.terminalContentReceived(content)))
          }
          return .none

        case .disconnected:
          state.isConnected = false
          state.terminalView = nil
          state.dashboard.remoteState = nil
          state.dashboard.selectedWorktreeID = nil
          return .none
        }

      // MARK: - Dashboard delegates
      case .dashboard(.delegate(.sendCommand(let command))):
        return .run { _ in
          try await remoteStateClient.send(command)
        } catch: { error, _ in
          logger.warning("Failed to send dashboard command: \(error)")
        }

      case .dashboard(.delegate(.worktreeSelected(let worktreeID))):
        if let worktreeState = state.dashboard.remoteState?.worktreeStates[worktreeID] {
          state.terminalView = TerminalViewFeature.State(
            worktreeID: worktreeID,
            worktreeState: worktreeState,
          )
        }
        return .none

      // MARK: - Terminal view delegates
      case .terminalView(.delegate(.sendCommand(let command))):
        return .run { _ in
          try await remoteStateClient.send(command)
        } catch: { error, _ in
          logger.warning("Failed to send terminal command: \(error)")
        }

      case .terminalView(.delegate(.requestTerminalContent(let surfaceID, let action))):
        return .run { _ in
          try await remoteStateClient.requestTerminalContent(
            TerminalContentRequest(surfaceID: surfaceID, action: action)
          )
        } catch: { error, _ in
          logger.warning("Failed to request terminal content: \(error)")
        }

      // MARK: - Dismiss terminal
      case .dismissTerminal:
        state.terminalView = nil
        return .none

      // MARK: - Disconnect
      case .disconnect:
        remoteStateClient.disconnect()
        state.isConnected = false
        state.terminalView = nil
        state.dashboard.remoteState = nil
        state.dashboard.selectedWorktreeID = nil
        return .send(.connection(.disconnect))

      // Pass-through for child actions
      case .connection, .dashboard, .terminalView:
        return .none
      }
    }
    .ifLet(\.terminalView, action: \.terminalView) {
      TerminalViewFeature()
    }
  }
}
