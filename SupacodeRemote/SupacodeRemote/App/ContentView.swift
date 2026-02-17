// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  let store: StoreOf<RemoteAppFeature>
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    if store.isConnected {
      if sizeClass == .regular {
        // iPad: Dashboard with terminal in detail pane
        NavigationStack {
          DashboardView(
            store: store.scope(state: \.dashboard, action: \.dashboard),
            terminalStore: store.scope(state: \.terminalView, action: \.terminalView),
          )
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Disconnect", systemImage: "wifi.slash") {
                store.send(.disconnect)
              }
            }
          }
        }
      } else if let terminalStore = store.scope(state: \.terminalView, action: \.terminalView) {
        // Compact: Terminal view pushed over dashboard
        NavigationStack {
          TerminalView(store: terminalStore)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                  store.send(.dismissTerminal)
                }
              }
              ToolbarItem(placement: .topBarTrailing) {
                Button("Disconnect", systemImage: "wifi.slash") {
                  store.send(.disconnect)
                }
              }
            }
        }
      } else {
        // Compact: Dashboard list
        NavigationStack {
          DashboardView(
            store: store.scope(state: \.dashboard, action: \.dashboard),
            terminalStore: nil,
          )
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Disconnect", systemImage: "wifi.slash") {
                store.send(.disconnect)
              }
            }
          }
        }
      }
    } else {
      ConnectionView(store: store.scope(state: \.connection, action: \.connection))
    }
  }
}
