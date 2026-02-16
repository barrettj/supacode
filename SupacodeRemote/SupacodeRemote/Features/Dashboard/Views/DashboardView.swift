// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import SwiftUI

struct DashboardView: View {
  let store: StoreOf<DashboardFeature>
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    if sizeClass == .regular {
      NavigationSplitView {
        worktreeList
      } detail: {
        if store.selectedWorktreeID != nil {
          Text("Terminal View")
            .font(.title2)
            .foregroundStyle(.secondary)
        } else {
          ContentUnavailableView("Select a worktree", systemImage: "terminal")
        }
      }
    } else {
      NavigationStack {
        worktreeList
      }
    }
  }

  private var worktreeList: some View {
    List(selection: Binding(
      get: { store.selectedWorktreeID },
      set: { id in
        if let id {
          store.send(.selectWorktree(id))
        }
      }
    )) {
      if let remoteState = store.remoteState {
        ForEach(remoteState.repositories) { repo in
          Section(repo.name) {
            ForEach(repo.worktreeIDs, id: \.self) { worktreeID in
              if let worktreeState = remoteState.worktreeStates[worktreeID] {
                WorktreeRowView(
                  worktreeState: worktreeState,
                  isSelected: store.selectedWorktreeID == worktreeID,
                )
                .tag(worktreeID)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Worktrees")
  }
}
