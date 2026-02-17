// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct WorktreeRowView: View {
  let worktreeState: RemoteWorktreeState
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(worktreeState.worktree.name)
          .font(.headline)

        Spacer()

        Circle()
          .fill(worktreeState.taskStatus == .running ? .tint : .secondary)
          .frame(width: 8, height: 8)

        if worktreeState.hasUnseenNotifications {
          Image(systemName: "bell.badge.fill")
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }

      Text("\(worktreeState.tabs.count) tab\(worktreeState.tabs.count == 1 ? "" : "s")")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let selectedTabID = worktreeState.selectedTabID,
        let splitTree = worktreeState.splitTrees[selectedTabID]
      {
        MiniSplitPreview(
          splitTree: splitTree,
          surfaces: worktreeState.surfaces,
          focusedSurfaceID: worktreeState.focusedSurfaceByTab[selectedTabID],
        )
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityDescription)
  }

  private var accessibilityDescription: String {
    var parts = [worktreeState.worktree.name]
    parts.append(worktreeState.taskStatus == .running ? "Task running" : "Task idle")
    if worktreeState.hasUnseenNotifications {
      parts.append("Has notifications")
    }
    parts.append("\(worktreeState.tabs.count) tab\(worktreeState.tabs.count == 1 ? "" : "s")")
    return parts.joined(separator: ", ")
  }
}
