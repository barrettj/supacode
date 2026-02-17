// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared

@Reducer
struct DashboardFeature {
  @ObservableState
  struct State: Equatable {
    var remoteState: RemoteState?
    var selectedWorktreeID: String?
    var isResyncing: Bool = false
  }

  enum Action {
    case stateSnapshotReceived(StateSnapshot)
    case stateDeltaReceived(StateDelta)
    case selectWorktree(String)
    case toggleRepositoryExpanded(String)
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate: Equatable {
    case sendCommand(RemoteCommand)
    case worktreeSelected(String)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .stateSnapshotReceived(let snapshot):
        state.remoteState = RemoteState(snapshot: snapshot)
        if state.selectedWorktreeID == nil,
          let firstRepo = snapshot.repositories.first,
          let firstWorktreeID = firstRepo.worktreeIDs.first
        {
          state.selectedWorktreeID = firstWorktreeID
        }
        return .none

      case .stateDeltaReceived(let delta):
        state.remoteState?.apply(delta)
        return .none

      case .toggleRepositoryExpanded(let repositoryID):
        if state.remoteState?.expandedRepositoryIDs.contains(repositoryID) == true {
          state.remoteState?.expandedRepositoryIDs.remove(repositoryID)
        } else {
          state.remoteState?.expandedRepositoryIDs.insert(repositoryID)
        }
        return .send(.delegate(.sendCommand(.toggleRepositoryExpanded(repositoryID: repositoryID))))

      case .selectWorktree(let worktreeID):
        state.selectedWorktreeID = worktreeID
        return .send(.delegate(.sendCommand(.selectWorktree(worktreeID: worktreeID))))
          .merge(with: .send(.delegate(.worktreeSelected(worktreeID))))

      case .delegate:
        return .none
      }
    }
  }
}
