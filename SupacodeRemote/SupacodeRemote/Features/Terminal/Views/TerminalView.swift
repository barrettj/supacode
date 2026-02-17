// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import SwiftUI

struct TerminalView: View {
  @Bindable var store: StoreOf<TerminalViewFeature>

  var body: some View {
    VStack(spacing: 0) {
      RemoteTabBarView(
        tabs: store.worktreeState.tabs,
        selectedTabID: store.worktreeState.selectedTabID,
        onSelect: { store.send(.selectTab($0)) },
        onCreate: { store.send(.createTab) },
        onClose: { store.send(.closeTab($0)) },
      )

      if let splitTree = store.currentSplitTree {
        SplitPreviewView(
          splitTree: splitTree,
          surfaces: store.worktreeState.surfaces,
          selectedSurfaceID: store.selectedSurfaceID,
          focusedSurfaceID: store.focusedSurfaceIDForCurrentTab,
          onSelectSurface: { store.send(.selectSurface($0)) },
          onSplitHorizontal: { store.send(.splitHorizontal) },
          onSplitVertical: { store.send(.splitVertical) },
          onCloseSurface: { store.send(.closeSurface) },
        )
        .frame(height: 80)
      }

      Divider()

      if let content = store.terminalContent {
        ANSITextView(lines: content.lines, rows: content.rows, cols: content.cols)
      } else {
        ContentUnavailableView("Select a terminal pane", systemImage: "rectangle.split.3x1")
          .frame(maxHeight: .infinity)
      }

      Divider()

      InputBarView(store: store)
    }
    .navigationTitle(store.worktreeState.worktree.name)
    .task { store.send(.task) }
  }
}
