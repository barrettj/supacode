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
      Section("Manual Connection") {
        HStack {
          TextField("Hostname or IP", text: $store.manualHostEntry)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Hostname or IP address")
          Button {
            store.send(.connectToManualHost)
          } label: {
            Image(systemName: "arrow.right.circle.fill")
          }
          .disabled(store.manualHostEntry.trimmingCharacters(in: .whitespaces).isEmpty)
          .accessibilityLabel("Connect to manual host")
        }
        Text("Enter a hostname or IP for Tailscale/remote connections. Port 7483 is used by default.")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
    }
    .navigationTitle("Connect")
    .sheet(isPresented: $store.isPINSheetPresented) {
      PINEntryView(store: store)
    }
    .task { store.send(.task) }
  }
}
