// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct QuickShortcutsView: View {
  let onSendKey: (RemoteKeyEvent) -> Void

  private static let shortcuts: [(label: String, event: RemoteKeyEvent)] = [
    ("Enter", RemoteKeyEvent(key: .enter, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("^C", RemoteKeyEvent(key: .character, modifiers: .ctrl, characterValue: "c")),
    ("Tab", RemoteKeyEvent(key: .tab, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("y", RemoteKeyEvent(key: .character, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: "y")),
    ("n", RemoteKeyEvent(key: .character, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: "n")),
    ("Esc", RemoteKeyEvent(key: .escape, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2191}", RemoteKeyEvent(key: .arrowUp, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2193}", RemoteKeyEvent(key: .arrowDown, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2190}", RemoteKeyEvent(key: .arrowLeft, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
    ("\u{2192}", RemoteKeyEvent(key: .arrowRight, modifiers: RemoteKeyEvent.RemoteModifiers(rawValue: 0), characterValue: nil)),
  ]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Self.shortcuts, id: \.label) { shortcut in
          Button(shortcut.label) { onSendKey(shortcut.event) }
            .buttonStyle(.bordered)
            .font(.caption.monospaced())
        }
      }
      .padding(.horizontal)
    }
    .frame(height: 44)
  }
}
