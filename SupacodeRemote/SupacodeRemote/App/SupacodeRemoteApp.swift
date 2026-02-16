// Created by Barrett Jacobsen

import ComposableArchitecture
import SwiftUI

@main
struct SupacodeRemoteApp: App {
  let store = Store(initialState: RemoteAppFeature.State()) {
    RemoteAppFeature()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
    }
  }
}
