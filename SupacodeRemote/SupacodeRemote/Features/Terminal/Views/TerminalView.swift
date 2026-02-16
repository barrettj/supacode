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
    .task { store.send(.task) }
  }
}

private struct InputBarView: View {
  @Bindable var store: StoreOf<TerminalViewFeature>

  var body: some View {
    HStack(spacing: 8) {
      TextField("Input", text: $store.inputText)
        .textFieldStyle(.roundedBorder)
        .font(.body.monospaced())
        .onSubmit { store.send(.sendInput) }

      Button { store.send(.sendInput) } label: {
        Image(systemName: "return")
      }
      .disabled(store.inputText.isEmpty || store.selectedSurfaceID == nil)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}
