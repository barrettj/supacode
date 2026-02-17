// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct SplitPreviewView: View {
  let splitTree: RemoteSplitTree
  let surfaces: [String: RemoteSurface]
  let selectedSurfaceID: String?
  let focusedSurfaceID: String?
  let onSelectSurface: (String) -> Void
  let onSplitHorizontal: () -> Void
  let onSplitVertical: () -> Void
  let onCloseSurface: () -> Void

  var body: some View {
    if let root = splitTree.root {
      InteractiveSplitNodeView(
        node: root,
        surfaces: surfaces,
        selectedSurfaceID: selectedSurfaceID,
        focusedSurfaceID: focusedSurfaceID,
        onSelectSurface: onSelectSurface,
        onSplitHorizontal: onSplitHorizontal,
        onSplitVertical: onSplitVertical,
        onCloseSurface: onCloseSurface,
      )
      .padding(.horizontal, 8)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct InteractiveSplitNodeView: View {
  let node: RemoteSplitTree.Node
  let surfaces: [String: RemoteSurface]
  let selectedSurfaceID: String?
  let focusedSurfaceID: String?
  let onSelectSurface: (String) -> Void
  let onSplitHorizontal: () -> Void
  let onSplitVertical: () -> Void
  let onCloseSurface: () -> Void

  var body: some View {
    switch node {
    case .leaf(let surfaceID):
      let isSelected = surfaceID == selectedSurfaceID
      let isFocused = surfaceID == focusedSurfaceID
      Button { onSelectSurface(surfaceID) } label: {
        RoundedRectangle(cornerRadius: 4)
          .fill(
            isSelected
              ? Color.accentColor.opacity(0.3)
              : isFocused ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 4)
              .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
          }
          .overlay {
            if let surface = surfaces[surfaceID] {
              Text(surface.title ?? surface.pwd ?? "")
                .font(.caption2)
                .monospaced()
                .lineLimit(1)
                .padding(2)
            }
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(splitPaneLabel(for: surfaceID))
      .contextMenu {
        Button("Split Right", systemImage: "rectangle.split.1x2") { onSplitHorizontal() }
        Button("Split Down", systemImage: "rectangle.split.2x1") { onSplitVertical() }
        Divider()
        Button("Close Pane", systemImage: "xmark", role: .destructive) { onCloseSurface() }
      }

    case .split(let split):
      let isHorizontal = split.direction == .horizontal
      let layout = isHorizontal
        ? AnyLayout(HStackLayout(spacing: 1))
        : AnyLayout(VStackLayout(spacing: 1))
      layout {
        InteractiveSplitNodeView(
          node: split.left,
          surfaces: surfaces,
          selectedSurfaceID: selectedSurfaceID,
          focusedSurfaceID: focusedSurfaceID,
          onSelectSurface: onSelectSurface,
          onSplitHorizontal: onSplitHorizontal,
          onSplitVertical: onSplitVertical,
          onCloseSurface: onCloseSurface,
        )
        .frame(
          maxWidth: isHorizontal ? .infinity : nil,
          maxHeight: !isHorizontal ? .infinity : nil,
        )
        .layoutPriority(split.ratio)
        InteractiveSplitNodeView(
          node: split.right,
          surfaces: surfaces,
          selectedSurfaceID: selectedSurfaceID,
          focusedSurfaceID: focusedSurfaceID,
          onSelectSurface: onSelectSurface,
          onSplitHorizontal: onSplitHorizontal,
          onSplitVertical: onSplitVertical,
          onCloseSurface: onCloseSurface,
        )
        .frame(
          maxWidth: isHorizontal ? .infinity : nil,
          maxHeight: !isHorizontal ? .infinity : nil,
        )
        .layoutPriority(1 - split.ratio)
      }
    }
  }

  private func splitPaneLabel(for surfaceID: String) -> String {
    if let surface = surfaces[surfaceID] {
      return surface.title ?? surface.pwd ?? "Terminal pane"
    }
    return "Terminal pane"
  }
}
