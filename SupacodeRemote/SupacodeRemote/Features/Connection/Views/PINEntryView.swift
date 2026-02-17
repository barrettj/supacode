// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

struct PINEntryView: View {
  @Bindable var store: StoreOf<ConnectionFeature>
  @FocusState private var isPINFocused: Bool

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        if let host = store.selectedHost {
          Text("Connect to \(host.name)")
            .font(.headline)
        }

        TextField("PIN", text: $store.pinEntry)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .font(.title.monospaced())
          .multilineTextAlignment(.center)
          .focused($isPINFocused)
          .accessibilityLabel("PIN code")

        switch store.connectionStatus {
        case .connecting, .authenticating:
          ProgressView()
        case .error(let message):
          Text(message)
            .foregroundStyle(.red)
            .font(.caption)
        default:
          EmptyView()
        }

        Button("Connect") {
          store.send(.connectWithPIN)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          store.connectionStatus == .connecting
            || store.connectionStatus == .authenticating
        )
        .accessibilityLabel("Connect to host")
      }
      .padding()
      .navigationTitle("Enter PIN")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.binding(.set(\.isPINSheetPresented, false)))
          }
        }
      }
      .onAppear { isPINFocused = true }
    }
  }
}
