// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct MiniSplitPreview: View {
  let splitTree: RemoteSplitTree
  let surfaces: [String: RemoteSurface]
  let focusedSurfaceID: String?

  var body: some View {
    if let root = splitTree.root {
      SplitNodeView(node: root, surfaces: surfaces, focusedSurfaceID: focusedSurfaceID)
        .frame(height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct SplitNodeView: View {
  let node: RemoteSplitTree.Node
  let surfaces: [String: RemoteSurface]
  let focusedSurfaceID: String?

  var body: some View {
    switch node {
    case .leaf(let surfaceID):
      let isFocused = surfaceID == focusedSurfaceID
      RoundedRectangle(cornerRadius: 4)
        .fill(isFocused ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
        .overlay {
          if let surface = surfaces[surfaceID] {
            Text(surface.title ?? surface.pwd ?? "")
              .font(.caption2)
              .monospaced()
              .lineLimit(1)
              .padding(2)
          }
        }
    case .split(let split):
      let isHorizontal = split.direction == .horizontal
      let layout = isHorizontal
        ? AnyLayout(HStackLayout(spacing: 1))
        : AnyLayout(VStackLayout(spacing: 1))
      layout {
        SplitNodeView(node: split.left, surfaces: surfaces, focusedSurfaceID: focusedSurfaceID)
          .frame(
            maxWidth: isHorizontal ? .infinity : nil,
            maxHeight: !isHorizontal ? .infinity : nil
          )
          .layoutPriority(split.ratio)
        SplitNodeView(node: split.right, surfaces: surfaces, focusedSurfaceID: focusedSurfaceID)
          .frame(
            maxWidth: isHorizontal ? .infinity : nil,
            maxHeight: !isHorizontal ? .infinity : nil
          )
          .layoutPriority(1 - split.ratio)
      }
    }
  }
}
