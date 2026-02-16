// Created by Barrett Jacobsen

import ComposableArchitecture
import Network
import SupacodeShared

@Reducer
struct ConnectionFeature {
  @ObservableState
  struct State: Equatable {
    var discoveredHosts: [DiscoveredHost] = []
    var connectionStatus: ConnectionStatus = .disconnected
    var pinEntry: String = ""
    var isPINSheetPresented = false
    var selectedHost: DiscoveredHost?
    var manualHostEntry: String = ""

    enum ConnectionStatus: Equatable {
      case disconnected
      case discovering
      case connecting
      case authenticating
      case connected
      case error(String)
    }
  }

  enum Action: BindableAction {
    case task
    case startDiscovery
    case hostsUpdated([DiscoveredHost])
    case selectHost(DiscoveredHost)
    case connectWithPIN
    case connectionResult(Result<Void, Error>)
    case disconnect
    case stateUpdate(RemoteStateUpdate)
    case delegate(Delegate)
    case binding(BindingAction<State>)

    @CasePathable
    enum Delegate: Equatable {
      case connected(StateSnapshot)
      case stateUpdate(RemoteStateUpdate)
    }
  }

  @Dependency(\.bonjourClient) var bonjourClient
  @Dependency(\.remoteStateClient) var remoteStateClient

  private enum CancelID {
    case discovery
    case stateUpdates
    case connection
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .task:
        return .send(.startDiscovery)

      case .startDiscovery:
        state.connectionStatus = .discovering
        return .run { send in
          for await hosts in bonjourClient.startDiscovery() {
            await send(.hostsUpdated(hosts))
          }
        }
        .cancellable(id: CancelID.discovery)

      case .hostsUpdated(let hosts):
        state.discoveredHosts = hosts
        return .none

      case .selectHost(let host):
        state.selectedHost = host
        state.pinEntry = ""
        state.isPINSheetPresented = true
        state.connectionStatus = .disconnected
        return .none

      case .connectWithPIN:
        guard let host = state.selectedHost else { return .none }
        state.connectionStatus = .connecting
        let pin = state.pinEntry
        let endpoint = host.endpoint
        return .run { send in
          try await remoteStateClient.connect(endpoint, pin)
          await send(.connectionResult(.success(())))
        } catch: { error, send in
          await send(.connectionResult(.failure(error)))
        }
        .cancellable(id: CancelID.connection)

      case .connectionResult(.success):
        state.connectionStatus = .authenticating
        return .run { send in
          for await update in remoteStateClient.stateUpdates() {
            await send(.stateUpdate(update))
          }
        }
        .cancellable(id: CancelID.stateUpdates)

      case .connectionResult(.failure(let error)):
        state.connectionStatus = .error(error.localizedDescription)
        return .none

      case .stateUpdate(let update):
        switch update {
        case .connected(let snapshot):
          state.connectionStatus = .connected
          state.isPINSheetPresented = false
          return .send(.delegate(.connected(snapshot)))

        case .delta, .terminalContent:
          return .send(.delegate(.stateUpdate(update)))

        case .disconnected(let reason):
          state.connectionStatus = .error(reason ?? "Disconnected")
          return .cancel(id: CancelID.stateUpdates)
        }

      case .disconnect:
        remoteStateClient.disconnect()
        state.connectionStatus = .disconnected
        state.selectedHost = nil
        return .merge(
          .cancel(id: CancelID.stateUpdates),
          .cancel(id: CancelID.connection)
        )

      case .delegate:
        return .none

      case .binding:
        return .none
      }
    }
  }
}
