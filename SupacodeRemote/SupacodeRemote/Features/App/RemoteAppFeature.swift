// Created by Barrett Jacobsen

import ComposableArchitecture

@Reducer
struct RemoteAppFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action {
    case appLaunched
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .appLaunched:
        return .none
      }
    }
  }
}
