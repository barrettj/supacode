// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

struct ConnectionView: View {
  @Bindable var store: StoreOf<ConnectionFeature>

  var body: some View {
    List {
      Section("Discovered") {
        ForEach(store.discoveredHosts) { host in
          Button {
            store.send(.selectHost(host))
          } label: {
            HStack {
              VStack(alignment: .leading) {
                Text(host.name)
                  .font(.headline)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
            }
          }
          .accessibilityLabel("Connect to \(host.name)")
        }
        if store.discoveredHosts.isEmpty {
          ContentUnavailableView {
            Label("Searching...", systemImage: "magnifyingglass")
          } description: {
            Text("Looking for Supacode instances on your network")
          }
        }
      }
    }
    .navigationTitle("Connect")
    .sheet(isPresented: $store.isPINSheetPresented) {
      PINEntryView(store: store)
    }
    .task { store.send(.task) }
  }
}
