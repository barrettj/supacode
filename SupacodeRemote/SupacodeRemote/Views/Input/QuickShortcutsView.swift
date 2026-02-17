// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct QuickShortcutsView: View {
  let onSendKey: (RemoteKeyEvent) -> Void

  private static let shortcuts: [(label: String, accessibilityLabel: String, event: RemoteKeyEvent)] = [
    ("Enter", "Send Enter", RemoteKeyEvent(key: .enter, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("^C", "Send Control-C", RemoteKeyEvent(key: .character, modifiers: .ctrl, characterValue: "c")),
    ("Tab", "Send Tab", RemoteKeyEvent(key: .tab, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("y", "Send y", RemoteKeyEvent(key: .character, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: "y")),
    ("n", "Send n", RemoteKeyEvent(key: .character, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: "n")),
    ("Esc", "Send Escape", RemoteKeyEvent(key: .escape, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2191}", "Send Arrow Up", RemoteKeyEvent(key: .arrowUp, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2193}", "Send Arrow Down", RemoteKeyEvent(key: .arrowDown, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2190}", "Send Arrow Left", RemoteKeyEvent(key: .arrowLeft, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2192}", "Send Arrow Right", RemoteKeyEvent(key: .arrowRight, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
  ]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Self.shortcuts, id: \.label) { shortcut in
          Button(shortcut.label) { onSendKey(shortcut.event) }
            .buttonStyle(.bordered)
            .font(.caption.monospaced())
            .accessibilityLabel(shortcut.accessibilityLabel)
        }
      }
      .padding(.horizontal)
    }
    .frame(height: 44)
  }
}
