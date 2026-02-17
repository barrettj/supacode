// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct TerminalKeyboardView: View {
  let onSendKey: (RemoteKeyEvent) -> Void
  @State private var ctrlActive = false
  @State private var altActive = false
  @State private var shiftActive = false
  @State private var characterInput = ""

  var body: some View {
    VStack(spacing: 8) {
      // Function keys row
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          keyButton("Esc", key: .escape)
          ForEach(1...12, id: \.self) { n in
            keyButton("F\(n)", key: RemoteKeyEvent.RemoteKey(rawValue: "f\(n)")!)
          }
        }
        .padding(.horizontal)
      }

      // Modifier toggles
      HStack(spacing: 8) {
        Toggle("Ctrl", isOn: $ctrlActive).toggleStyle(.button).font(.caption)
          .accessibilityLabel("Control modifier")
        Toggle("Alt", isOn: $altActive).toggleStyle(.button).font(.caption)
          .accessibilityLabel("Alt modifier")
        Toggle("Shift", isOn: $shiftActive).toggleStyle(.button).font(.caption)
          .accessibilityLabel("Shift modifier")
      }

      // Arrow keys + nav keys
      HStack(spacing: 16) {
        VStack(spacing: 4) {
          keyButton("Home", key: .home)
          keyButton("End", key: .end)
        }
        VStack(spacing: 2) {
          keyButton("\u{2191}", key: .arrowUp)
          HStack(spacing: 2) {
            keyButton("\u{2190}", key: .arrowLeft)
            keyButton("\u{2193}", key: .arrowDown)
            keyButton("\u{2192}", key: .arrowRight)
          }
        }
        VStack(spacing: 4) {
          keyButton("PgUp", key: .pageUp)
          keyButton("PgDn", key: .pageDown)
        }
      }

      // Modified character input (e.g. type 'c' with Ctrl = Ctrl+C)
      HStack(spacing: 8) {
        TextField("Key", text: $characterInput)
          .textFieldStyle(.roundedBorder)
          .font(.caption.monospaced())
          .frame(width: 60)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .onChange(of: characterInput) { _, newValue in
            guard let char = newValue.last else { return }
            onSendKey(RemoteKeyEvent(key: .character, modifiers: currentModifiers(), characterValue: String(char)))
            characterInput = ""
            resetModifiers()
          }

        Text("Type key with modifiers")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
  }

  private func currentModifiers() -> RemoteKeyEvent.RemoteModifiers {
    var mods = RemoteKeyEvent.RemoteModifiers(rawValue: 0)
    if ctrlActive { mods.insert(.ctrl) }
    if altActive { mods.insert(.alt) }
    if shiftActive { mods.insert(.shift) }
    return mods
  }

  private func resetModifiers() {
    ctrlActive = false
    altActive = false
    shiftActive = false
  }

  private func keyButton(_ label: String, key: RemoteKeyEvent.RemoteKey) -> some View {
    Button(label) {
      onSendKey(RemoteKeyEvent(key: key, modifiers: currentModifiers(), characterValue: nil))
      resetModifiers()
    }
    .buttonStyle(.bordered)
    .font(.caption.monospaced())
    .accessibilityLabel("Send \(label)")
    .help("Send \(label) key")
  }
}
