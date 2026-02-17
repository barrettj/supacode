//
//  supacodeApp.swift
//  supacode
//
//  Created by khoi on 20/1/26.
//

import AppKit
import ComposableArchitecture
import Foundation
import GhosttyKit
import PostHog
import Sentry
import Sharing
import SupacodeShared
import SwiftUI

private let logger = SupaLogger("App")

private enum GhosttyCLI {
  static let argv: [UnsafeMutablePointer<CChar>?] = {
    var args: [UnsafeMutablePointer<CChar>?] = []
    let executable = CommandLine.arguments.first ?? "supacode"
    args.append(strdup(executable))
    for shortcut in AppShortcuts.all {
      args.append(strdup("--keybind=\(shortcut.ghosttyKeybind)=unbind"))
    }
    args.append(nil)
    return args
  }()
}

@MainActor
final class SupacodeAppDelegate: NSObject, NSApplicationDelegate {
  var appStore: StoreOf<AppFeature>?

  func applicationDidFinishLaunching(_ notification: Notification) {
    appStore?.send(.appLaunched)
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    let app = NSApplication.shared
    guard !app.windows.contains(where: \.isVisible) else { return }
    _ = showMainWindow(from: app)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if flag { return true }
    return showMainWindow(from: sender) ? false : true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  private func mainWindow(from sender: NSApplication) -> NSWindow? {
    if let window = sender.windows.first(where: { $0.identifier?.rawValue == "main" }) {
      return window
    }
    if let window = sender.windows.first(where: { $0.identifier?.rawValue != "settings" }) {
      return window
    }
    return sender.windows.first
  }

  private func showMainWindow(from sender: NSApplication) -> Bool {
    guard let window = mainWindow(from: sender) else { return false }
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    sender.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    return true
  }
}

@main
@MainActor
struct SupacodeApp: App {
  @NSApplicationDelegateAdaptor(SupacodeAppDelegate.self) private var appDelegate
  @State private var ghostty: GhosttyRuntime
  @State private var ghosttyShortcuts: GhosttyShortcutManager
  @State private var terminalManager: WorktreeTerminalManager
  @State private var worktreeInfoWatcher: WorktreeInfoWatcherManager
  @State private var commandKeyObserver: CommandKeyObserver
  @State private var remoteControlServer: RemoteControlServer
  @State private var terminalContentStreamer: TerminalContentStreamer
  @State private var commandRouter: CommandRouter
  @State private var store: StoreOf<AppFeature>

  @MainActor init() {
    NSWindow.allowsAutomaticWindowTabbing = false
    UserDefaults.standard.set(200, forKey: "NSInitialToolTipDelay")
    @Shared(.settingsFile) var settingsFile
    let initialSettings = settingsFile.global
    #if !DEBUG
      if initialSettings.crashReportsEnabled {
        SentrySDK.start { options in
          options.dsn = "__SENTRY_DSN__"
          options.tracesSampleRate = 1.0
          options.enableAppHangTracking = false
        }
      }
      if initialSettings.analyticsEnabled {
        let posthogAPIKey = "__POSTHOG_API_KEY__"
        let posthogHost = "__POSTHOG_HOST__"
        let config = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        config.enableSwizzling = false
        PostHogSDK.shared.setup(config)
        if let hardwareUUID = HardwareInfo.uuid {
          PostHogSDK.shared.identify(hardwareUUID)
        }
      }
    #endif
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }
    GhosttyCLI.argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1))
      let argv = UnsafeMutablePointer(mutating: buffer.baseAddress)
      if ghostty_init(argc, argv) != GHOSTTY_SUCCESS {
        preconditionFailure("ghostty_init failed")
      }
    }
    let runtime = GhosttyRuntime()
    _ghostty = State(initialValue: runtime)
    let shortcuts = GhosttyShortcutManager(runtime: runtime)
    _ghosttyShortcuts = State(initialValue: shortcuts)
    let terminalManager = WorktreeTerminalManager(runtime: runtime)
    _terminalManager = State(initialValue: terminalManager)
    let worktreeInfoWatcher = WorktreeInfoWatcherManager()
    _worktreeInfoWatcher = State(initialValue: worktreeInfoWatcher)
    let keyObserver = CommandKeyObserver()
    _commandKeyObserver = State(initialValue: keyObserver)
    let server = RemoteControlServer()
    _remoteControlServer = State(initialValue: server)
    let contentStreamer = TerminalContentStreamer(terminalManager: terminalManager)
    _terminalContentStreamer = State(initialValue: contentStreamer)
    // storeRef is captured by closures that run after init completes
    nonisolated(unsafe) var storeRef: StoreOf<AppFeature>?
    let appStore = Store(
      initialState: AppFeature.State(settings: SettingsFeature.State(settings: initialSettings))
    ) {
      AppFeature()
        .logActions()
    } withDependencies: { values in
      values.terminalClient = TerminalClient(
        send: { command in
          terminalManager.handleCommand(command)
        },
        events: {
          terminalManager.eventStream()
        }
      )
      values.worktreeInfoWatcher = WorktreeInfoWatcherClient(
        send: { command in
          worktreeInfoWatcher.handleCommand(command)
        },
        events: {
          worktreeInfoWatcher.eventStream()
        }
      )
      values.remoteControlClient = RemoteControlClient(
        start: { pin, port, name in
          try server.start(pin: pin, port: port, name: name)
        },
        stop: {
          server.stop()
          contentStreamer.stopAllStreaming()
        },
        isRunning: {
          server.isRunning
        },
        broadcastStateUpdate: {
          guard server.isRunning, !server.connectedDevices.isEmpty,
            let store = storeRef
          else { return }
          let snapshot = StateSerializer.serializeSnapshot(
            repositories: store.repositories.repositories.elements.map { $0 },
            selectedWorktreeID: store.repositories.selectedWorktreeID,
            terminalManager: terminalManager,
            pinnedWorktreeIDs: store.repositories.pinnedWorktreeIDs,
            worktreeInfoByID: store.repositories.worktreeInfoByID,
          )
          do {
            let message = try RemoteMessage(type: .stateSnapshot, payload: snapshot)
            server.broadcast(message)
          } catch {
            logger.warning("Failed to encode state snapshot: \(error)")
          }
        },
        broadcastDelta: { delta in
          guard server.isRunning, !server.connectedDevices.isEmpty else { return }
          do {
            let message = try RemoteMessage(type: .stateDelta, payload: delta)
            server.broadcast(message)
          } catch {
            logger.warning("Failed to encode state delta: \(error)")
          }
        },
        connectedDevices: {
          server.connectedDevices
        },
        disconnect: { deviceID in
          contentStreamer.stopAllStreaming(sessionID: deviceID)
          server.disconnect(deviceID: deviceID)
        },
      )
    }
    storeRef = appStore
    _store = State(initialValue: appStore)
    let commandRouter = CommandRouter(
      terminalManager: terminalManager,
      repositories: {
        appStore.repositories.repositories.elements.map { $0 }
      },
      onSelectWorktree: { worktreeID in
        appStore.send(.repositories(.selectWorktree(worktreeID)))
      },
      onSelectNextWorktree: {
        appStore.send(.repositories(.selectNextWorktree))
      },
      onSelectPreviousWorktree: {
        appStore.send(.repositories(.selectPreviousWorktree))
      },
    )
    _commandRouter = State(initialValue: commandRouter)
    server.onCommandReceived = { _, command in
      commandRouter.route(command)
    }
    server.onSessionAuthenticated = { sessionID in
      guard let store = storeRef else { return }
      let snapshot = StateSerializer.serializeSnapshot(
        repositories: store.repositories.repositories.elements.map { $0 },
        selectedWorktreeID: store.repositories.selectedWorktreeID,
        terminalManager: terminalManager,
        pinnedWorktreeIDs: store.repositories.pinnedWorktreeIDs,
        worktreeInfoByID: store.repositories.worktreeInfoByID,
      )
      do {
        let message = try RemoteMessage(type: .stateSnapshot, payload: snapshot)
        server.sendToSession(sessionID, message: message)
      } catch {
        logger.warning("Failed to send initial snapshot to session: \(error)")
      }
    }
    server.onTerminalContentRequested = { sessionID, request in
      switch request.action {
      case .startStreaming:
        contentStreamer.startStreaming(sessionID: sessionID, surfaceID: request.surfaceID) { content in
          do {
            let message = try RemoteMessage(type: .terminalContent, payload: content)
            server.sendToSession(sessionID, message: message)
          } catch {
            logger.warning("Failed to encode terminal content for streaming: \(error)")
          }
        }
      case .stopStreaming:
        contentStreamer.stopStreaming(sessionID: sessionID, surfaceID: request.surfaceID)
      case .requestOnce:
        if let content = contentStreamer.readContentOnce(surfaceID: request.surfaceID) {
          do {
            let message = try RemoteMessage(type: .terminalContent, payload: content)
            server.sendToSession(sessionID, message: message)
          } catch {
            logger.warning("Failed to encode terminal content for one-time read: \(error)")
          }
        }
      }
    }
    appDelegate.appStore = appStore
    SettingsWindowManager.shared.configure(
      store: appStore,
      ghosttyShortcuts: shortcuts,
      commandKeyObserver: keyObserver
    )
  }

  var body: some Scene {
    Window("Supacode", id: "main") {
      GhosttyColorSchemeSyncView(ghostty: ghostty) {
        ContentView(store: store, terminalManager: terminalManager)
          .environment(ghosttyShortcuts)
          .environment(commandKeyObserver)
      }
      .preferredColorScheme(store.settings.appearanceMode.colorScheme)
    }
    .environment(ghosttyShortcuts)
    .environment(commandKeyObserver)
    .commands {
      WorktreeCommands(store: store)
      SidebarCommands()
      TerminalCommands(ghosttyShortcuts: ghosttyShortcuts)
      CommandGroup(after: .textEditing) {
        Button("Command Palette") {
          store.send(.commandPalette(.togglePresented))
        }
        .keyboardShortcut("p", modifiers: .command)
        .help("Command Palette (⌘P)")
      }
      UpdateCommands(store: store.scope(state: \.updates, action: \.updates))
      CommandGroup(replacing: .windowArrangement) {
        Button("Minimize") {
          NSApp.keyWindow?.miniaturize(nil)
        }
        .keyboardShortcut("m")
        .help("Minimize (⌘M)")
        Button("Zoom") {
          NSApp.keyWindow?.zoom(nil)
        }
        .help("Zoom (no shortcut)")
      }
      CommandGroup(replacing: .appSettings) {
        Button("Settings...") {
          SettingsWindowManager.shared.show()
        }
        .keyboardShortcut(
          AppShortcuts.openSettings.keyEquivalent,
          modifiers: AppShortcuts.openSettings.modifiers
        )
      }
      CommandGroup(replacing: .appTermination) {
        Button("Quit Supacode") {
          store.send(.requestQuit)
        }
        .keyboardShortcut("q")
        .help("Quit Supacode (⌘Q)")
      }
    }
  }
}
