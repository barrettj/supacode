// Created by Barrett Jacobsen

import SwiftUI

struct ConnectedDevicesToolbarButton: View {
  @Environment(RemoteControlServer.self) private var server
  @State private var isPopoverPresented = false

  var body: some View {
    if !server.connectedDevices.isEmpty {
      Button {
        isPopoverPresented.toggle()
      } label: {
        Image(systemName: "iphone")
          .accessibilityLabel("Connected devices")
      }
      .help("Connected devices (\(server.connectedDevices.count))")
      .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
        ConnectedDevicesPopoverContent(
          devices: server.connectedDevices,
          onDisconnect: { deviceID in
            server.disconnect(deviceID: deviceID)
          }
        )
      }
    }
  }
}

private struct ConnectedDevicesPopoverContent: View {
  let devices: [RemoteControlServer.ConnectedDevice]
  let onDisconnect: (UUID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Connected Devices")
        .font(.headline)

      Divider()

      ForEach(devices) { device in
        HStack {
          Image(systemName: "iphone")
            .foregroundStyle(.secondary)
          Text(device.deviceName)
            .font(.body)
          Spacer(minLength: 16)
          Button {
            onDisconnect(device.id)
          } label: {
            Image(systemName: "xmark.circle")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help("Disconnect \(device.deviceName)")
        }
      }
    }
    .padding(12)
    .frame(minWidth: 200)
  }
}
