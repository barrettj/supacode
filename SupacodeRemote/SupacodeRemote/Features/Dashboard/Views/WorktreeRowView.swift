// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct WorktreeRowView: View {
  let worktreeState: RemoteWorktreeState
  let isSelected: Bool

  private var worktree: RemoteWorktree { worktreeState.worktree }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        ZStack {
          if worktreeState.hasUnseenNotifications {
            Image(systemName: "bell.fill")
              .font(.caption)
              .foregroundStyle(.orange)
              .accessibilityLabel("Unread notifications")
          } else {
            Image(systemName: branchIconName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }

          if showsSpinner {
            ProgressView()
              .controlSize(.small)
          }
        }
        .frame(width: 16, height: 16)

        Text(worktree.name)
          .font(.body)
          .lineLimit(1)

        Spacer(minLength: 4)

        if worktreeState.isRunScriptRunning {
          Image(systemName: "play.fill")
            .font(.caption)
            .foregroundStyle(isSelected ? Color.primary : Color.green)
            .accessibilityLabel("Run script active")
        }

        if let added = worktree.addedLines, let removed = worktree.removedLines {
          HStack(spacing: 4) {
            Text("+\(added)")
              .foregroundStyle(isSelected ? Color.secondary : Color.green)
            Text("-\(removed)")
              .foregroundStyle(isSelected ? Color.secondary : Color.red)
          }
          .font(.caption)
          .lineLimit(1)
          .monospacedDigit()
        }
      }

      HStack(spacing: 4) {
        detailText
          .font(.caption)
          .lineLimit(1)
          .foregroundStyle(.secondary)

        Spacer(minLength: 0)
      }
      .padding(.leading, 22)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityDescription)
  }

  private var branchIconName: String {
    if worktree.isMainWorktree {
      return "star.fill"
    } else if worktree.isPinned {
      return "pin.fill"
    } else {
      return "arrow.triangle.branch"
    }
  }

  private var showsSpinner: Bool {
    worktreeState.taskStatus == .running
  }

  private var detailText: Text {
    var result = AttributedString()

    func appendSeparator() {
      if !result.characters.isEmpty {
        var sep = AttributedString(" \u{2022} ")
        sep.foregroundColor = .secondary
        result.append(sep)
      }
    }

    if !worktree.detail.isEmpty {
      var segment = AttributedString(worktree.detail)
      segment.foregroundColor = .secondary
      result.append(segment)
    }

    if let prNumber = worktree.pullRequestNumber {
      appendSeparator()
      var segment = AttributedString("PR #\(prNumber)")
      segment.foregroundColor = .secondary
      result.append(segment)

      if worktree.pullRequestState == "MERGED" {
        appendSeparator()
        var merged = AttributedString("Merged")
        merged.foregroundColor = isSelected ? .secondary : .purple
        result.append(merged)
      }
    }

    let tabCount = worktreeState.tabs.count
    appendSeparator()
    var tabSegment = AttributedString("\(tabCount) tab\(tabCount == 1 ? "" : "s")")
    tabSegment.foregroundColor = .secondary
    result.append(tabSegment)

    return Text(result)
  }

  private var accessibilityDescription: String {
    var parts = [worktree.name]
    if worktree.isMainWorktree {
      parts.append("Main worktree")
    } else if worktree.isPinned {
      parts.append("Pinned")
    }
    parts.append(worktreeState.taskStatus == .running ? "Task running" : "Task idle")
    if worktreeState.hasUnseenNotifications {
      parts.append("Has notifications")
    }
    if worktreeState.isRunScriptRunning {
      parts.append("Run script active")
    }
    if let added = worktree.addedLines, let removed = worktree.removedLines {
      parts.append("\(added) added, \(removed) removed")
    }
    parts.append("\(worktreeState.tabs.count) tab\(worktreeState.tabs.count == 1 ? "" : "s")")
    return parts.joined(separator: ", ")
  }
}
