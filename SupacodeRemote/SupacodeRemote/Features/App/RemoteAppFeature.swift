// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared

private let logger = RemoteLogger("RemoteApp")

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
    case resyncTimedOut
    case reconnectFailed
    case connection(ConnectionFeature.Action)
    case dashboard(DashboardFeature.Action)
    case terminalView(TerminalViewFeature.Action)
    case dismissTerminal
    case disconnect
  }

  @Dependency(\.remoteStateClient) var remoteStateClient

  private enum CancelID {
    case resyncTimeout
  }

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
        guard state.isConnected else { return .none }
        let isSocketAlive = remoteStateClient.isConnected()
        if isSocketAlive {
          // Connection alive — request fresh state
          state.dashboard.isResyncing = true
          return .merge(
            .run { send in
              try await remoteStateClient.send(.requestResync)
            } catch: { error, send in
              logger.warning("Failed to send resync: \(error)")
              await send(.resyncTimedOut)
            },
            .run { send in
              try await Task.sleep(for: .seconds(5))
              await send(.resyncTimedOut)
            }
            .cancellable(id: CancelID.resyncTimeout)
          )
        } else {
          // Connection dead — auto-reconnect
          state.dashboard.isResyncing = true
          return .send(.connection(.reconnect))
        }

      case .resyncTimedOut:
        if state.dashboard.isResyncing {
          // Resync didn't complete in time — try reconnecting
          return .send(.connection(.reconnect))
        }
        return .none

      case .reconnectFailed:
        state.dashboard.isResyncing = false
        state.isConnected = false
        state.terminalView = nil
        state.dashboard.remoteState = nil
        state.dashboard.selectedWorktreeID = nil
        return .none

      // MARK: - Connection delegates
      case .connection(.delegate(.connected(let snapshot))):
        let wasResyncing = state.dashboard.isResyncing
        state.isConnected = true
        state.dashboard.isResyncing = false

        if wasResyncing {
          // Resync: sync selection from Mac
          if let selectedID = snapshot.selectedWorktreeID,
            let worktreeState = snapshot.worktreeStates[selectedID]
          {
            state.terminalView = TerminalViewFeature.State(
              worktreeID: selectedID,
              worktreeState: worktreeState,
            )
            state.dashboard.selectedWorktreeID = selectedID
          } else if let terminalView = state.terminalView,
            let updatedState = snapshot.worktreeStates[terminalView.worktreeID]
          {
            state.terminalView?.worktreeState = updatedState
          } else {
            state.terminalView = nil
          }
        } else {
          // Fresh connect: preserve current terminal view
          if let terminalView = state.terminalView,
            let updatedState = snapshot.worktreeStates[terminalView.worktreeID]
          {
            state.terminalView?.worktreeState = updatedState
          }
        }
        return .send(.dashboard(.stateSnapshotReceived(snapshot)))
          .merge(with: .cancel(id: CancelID.resyncTimeout))

      case .connection(.delegate(.stateUpdate(let update))):
        switch update {
        case .connected:
          // Handled by .connection(.delegate(.connected)) above
          return .none

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
        return .merge(
          .send(.connection(.disconnect)),
          .cancel(id: CancelID.resyncTimeout),
        )

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
