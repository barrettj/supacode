// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import SwiftUI

struct DashboardView: View {
  let store: StoreOf<DashboardFeature>
  let terminalStore: StoreOf<TerminalViewFeature>?
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    if sizeClass == .regular {
      NavigationSplitView {
        worktreeList
      } detail: {
        if let terminalStore {
          TerminalView(store: terminalStore)
        } else {
          ContentUnavailableView("Select a worktree", systemImage: "terminal")
        }
      }
    } else {
      worktreeList
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
        if remoteState.repositories.isEmpty {
          ContentUnavailableView {
            Label("Waiting for Mac\u{2026}", systemImage: "desktopcomputer")
          } description: {
            Text("The Mac app is still loading.")
          }
        } else {
          ForEach(remoteState.repositories) { repo in
            let isExpanded = remoteState.expandedRepositoryIDs.contains(repo.id)
            Section {
              if isExpanded {
                ForEach(repo.worktreeIDs, id: \.self) { worktreeID in
                  if let worktreeState = remoteState.worktreeStates[worktreeID] {
                    WorktreeRowView(
                      worktreeState: worktreeState,
                      isSelected: store.selectedWorktreeID == worktreeID,
                    )
                    .tag(worktreeID)
                    .accessibilityLabel(worktreeState.worktree.name)
                  }
                }
              }
            } header: {
              Button {
                store.send(.toggleRepositoryExpanded(repo.id))
              } label: {
                HStack {
                  Text(repo.name)
                  Spacer()
                  Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeOut(duration: 0.2), value: isExpanded)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(isExpanded ? "Collapse \(repo.name)" : "Expand \(repo.name)")
            }
          }
        }
      }
    }
    .overlay {
      if store.isResyncing {
        ZStack {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
          ProgressView("Reconnecting\u{2026}")
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
    .navigationTitle("Supacode Remote")
  }
}
