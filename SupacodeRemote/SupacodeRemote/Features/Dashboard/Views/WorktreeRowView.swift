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
          .fill(worktreeState.taskStatus == .running ? Color.orange : Color.green)
          .frame(width: 8, height: 8)

        if worktreeState.hasUnseenNotifications {
          Image(systemName: "bell.badge.fill")
            .foregroundStyle(.red)
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
  }
}
