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
            Text(
              "Allow iOS devices on your local network to control Supacode remotely. Data is sent unencrypted over your local network and protected by PIN authentication."
            )
            .foregroundStyle(.secondary)
            .font(.callout)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if store.remoteControlEnabled {
          Section("Display Name") {
            VStack(alignment: .leading) {
              TextField("Name", text: $store.remoteControlName)
                .help("Name shown to iOS devices when discovering this Mac")
              Text("How this Mac appears to iOS devices on the network.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

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
                let digits = String(newValue.filter(\.isNumber).prefix(6))
                let padded = String(repeating: "0", count: max(0, 6 - digits.count)) + digits
                if padded != newValue {
                  store.send(.set(\.remoteControlPin, padded))
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
                .onChange(of: store.remoteControlPort) { _, newValue in
                  let clamped = min(max(newValue, 1024), 65535)
                  if clamped != newValue {
                    store.send(.set(\.remoteControlPort, clamped))
                  }
                }
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
