// Created by Barrett Jacobsen

import ComposableArchitecture
import SupacodeShared
import SwiftUI

struct InputBarView: View {
  @Bindable var store: StoreOf<TerminalViewFeature>
  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Always-visible command text field + send + mode picker
      // The text field is here so voice/shortcuts can populate it before sending
      // But it only gets keyboard focus in .keyboard mode
      HStack(spacing: 8) {
        TextField("Command...", text: $store.inputText)
          .textFieldStyle(.roundedBorder)
          .font(.body.monospaced())
          .focused($isTextFieldFocused)
          .onSubmit { store.send(.sendInput) }
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)

        Button { store.send(.sendInput) } label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
        }
        .disabled(store.inputText.isEmpty || store.selectedSurfaceID == nil)

        Menu {
          ForEach(TerminalViewFeature.State.InputMode.allCases, id: \.self) { mode in
            Button {
              store.send(.switchInputMode(mode))
            } label: {
              Label(mode.label, systemImage: mode.icon)
            }
          }
        } label: {
          Image(systemName: store.inputMode.icon)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)

      // Mode-specific area (replaces the iOS keyboard)
      switch store.inputMode {
      case .quickShortcuts:
        QuickShortcutsView(onSendKey: { store.send(.sendKey($0)) })
      case .voice:
        VoiceInputView(onTranscribed: { text in
          store.send(.binding(.set(\.inputText, text)))
        })
      case .terminalKeyboard:
        TerminalKeyboardView(onSendKey: { store.send(.sendKey($0)) })
      case .keyboard:
        // iOS keyboard appears naturally via @FocusState
        EmptyView()
      }
    }
    .onChange(of: store.inputMode) { _, newMode in
      // Only show iOS keyboard in keyboard mode
      isTextFieldFocused = newMode == .keyboard
    }
  }
}

extension TerminalViewFeature.State.InputMode {
  var label: String {
    switch self {
    case .voice: "Voice"
    case .keyboard: "Keyboard"
    case .terminalKeyboard: "Terminal Keys"
    case .quickShortcuts: "Shortcuts"
    }
  }

  var icon: String {
    switch self {
    case .voice: "mic"
    case .keyboard: "keyboard"
    case .terminalKeyboard: "command.square"
    case .quickShortcuts: "bolt.horizontal"
    }
  }
}
