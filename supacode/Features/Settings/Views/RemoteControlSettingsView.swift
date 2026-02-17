// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

struct RemoteControlSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>
  @State private var showPinCode = false

  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section("Remote Control") {
          VStack(alignment: .leading) {
            Toggle(
              "Enable Remote Control",
              isOn: $store.remoteControlEnabled
            )
            .help("Allow iOS devices on your network to control Supacode")
            Text("Allow iOS devices on your local network to control Supacode remotely.")
              .foregroundStyle(.secondary)
              .font(.callout)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if store.remoteControlEnabled {
          Section("Security") {
            VStack(alignment: .leading) {
              HStack {
                if showPinCode {
                  TextField("PIN Code", text: $store.remoteControlPin)
                    .help("6-digit PIN required for iOS devices to connect")
                } else {
                  SecureField("PIN Code", text: $store.remoteControlPin)
                    .help("6-digit PIN required for iOS devices to connect")
                }
                Toggle("Show", isOn: $showPinCode)
                  .toggleStyle(.checkbox)
              }
              .onChange(of: store.remoteControlPin) { _, newValue in
                let filtered = String(newValue.filter(\.isNumber).prefix(6))
                if filtered != newValue {
                  store.remoteControlPin = filtered
                }
              }
              Text("Set a 6-digit PIN that iOS devices must enter to connect.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          Section("Network") {
            VStack(alignment: .leading) {
              TextField("Port", value: $store.remoteControlPort, format: .number.grouping(.never))
                .help("TCP port for the remote control server (default: 7483)")
              Text("TCP port for the remote control server. Change requires restart of remote control.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .formStyle(.grouped)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
