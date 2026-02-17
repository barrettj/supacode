// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  let store: StoreOf<RemoteAppFeature>

  var body: some View {
    if store.isConnected {
      if let terminalStore = store.scope(state: \.terminalView, action: \.terminalView) {
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
        NavigationStack {
          DashboardView(store: store.scope(state: \.dashboard, action: \.dashboard))
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
