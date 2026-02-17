// Created by Barrett Jacobsen

import ComposableArchitecture
import Foundation
import Network
import SupacodeShared

private let logger = RemoteLogger("Connection")

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
    var savedCredentials: [String: HostCredentials] = HostCredentials.loadAll()

    enum ConnectionStatus: Equatable {
      case disconnected
      case discovering
      case connecting
      case authenticating
      case connected
      case error(String)
    }
  }

  struct HostCredentials: Equatable, Codable {
    var pin: String
    var sessionToken: String?

    private static let storageKey = "savedHostCredentials"

    static func loadAll() -> [String: HostCredentials] {
      guard let data = UserDefaults.standard.data(forKey: storageKey),
        let decoded = try? JSONDecoder().decode([String: HostCredentials].self, from: data)
      else { return [:] }
      return decoded
    }

    static func saveAll(_ credentials: [String: HostCredentials]) {
      do {
        let data = try JSONEncoder().encode(credentials)
        UserDefaults.standard.set(data, forKey: storageKey)
      } catch {
        logger.warning("Failed to save host credentials: \(error)")
      }
    }
  }

  struct ConnectionSuccess: Equatable {
    let hostID: String
    let pin: String
    let sessionToken: String?
  }

  enum Action: BindableAction {
    case task
    case startDiscovery
    case hostsUpdated([DiscoveredHost])
    case selectHost(DiscoveredHost)
    case connectWithPIN
    case connectToManualHost
    case connectionResult(Result<ConnectionSuccess, Error>)
    case reconnect
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
        if let saved = state.savedCredentials[host.id] {
          state.pinEntry = saved.pin
          state.connectionStatus = .disconnected
          return .send(.connectWithPIN)
        }
        state.pinEntry = ""
        state.isPINSheetPresented = true
        state.connectionStatus = .disconnected
        return .none

      case .connectToManualHost:
        let input = state.manualHostEntry.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return .none }

        // Parse host:port or just host (default port 7483)
        let host: String
        let port: UInt16
        if let colonIndex = input.lastIndex(of: ":"),
          let portNumber = UInt16(input[input.index(after: colonIndex)...])
        {
          host = String(input[..<colonIndex])
          port = portNumber
        } else {
          host = input
          port = 7483
        }

        let endpoint = NWEndpoint.hostPort(
          host: NWEndpoint.Host(host),
          port: NWEndpoint.Port(rawValue: port)!
        )
        let manualHost = DiscoveredHost(
          id: "manual-\(host):\(port)",
          name: host,
          endpoint: endpoint,
        )
        state.selectedHost = manualHost
        state.pinEntry = state.savedCredentials[manualHost.id]?.pin ?? ""
        state.isPINSheetPresented = true
        state.connectionStatus = .disconnected
        return .none

      case .connectWithPIN:
        guard let host = state.selectedHost else { return .none }
        state.connectionStatus = .connecting
        let pin = state.pinEntry
        let endpoint = host.endpoint
        let hostID = host.id
        let existingToken = state.savedCredentials[hostID]?.sessionToken
        return .run { send in
          async let updates: Void = {
            for await update in remoteStateClient.stateUpdates() {
              await send(.stateUpdate(update))
            }
          }()
          do {
            let token = try await withThrowingTaskGroup(of: String?.self) { group in
              group.addTask {
                try await remoteStateClient.connect(endpoint, pin, existingToken)
              }
              group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw RemoteStateError.timeout
              }
              guard let result = try await group.next() else {
                throw RemoteStateError.timeout
              }
              group.cancelAll()
              return result
            }
            await send(.connectionResult(.success(ConnectionSuccess(hostID: hostID, pin: pin, sessionToken: token))))
          } catch {
            await send(.connectionResult(.failure(error)))
          }
          await updates
        }
        .cancellable(id: CancelID.connection)

      case .connectionResult(.success(let success)):
        // Don't set .authenticating here — the stateUpdates stream may have already
        // yielded .connected(snapshot) before connect() returned, so setting
        // .authenticating would regress the status.
        state.savedCredentials[success.hostID] = HostCredentials(
          pin: success.pin,
          sessionToken: success.sessionToken,
        )
        HostCredentials.saveAll(state.savedCredentials)
        return .none

      case .connectionResult(.failure(let error)):
        state.connectionStatus = .error(error.localizedDescription)
        // If we auto-connected (PIN sheet not shown), clear saved credentials and show PIN sheet
        if !state.isPINSheetPresented, let host = state.selectedHost {
          state.savedCredentials.removeValue(forKey: host.id)
          HostCredentials.saveAll(state.savedCredentials)
          state.pinEntry = ""
          state.isPINSheetPresented = true
        }
        // Disconnect and cancel in-flight connection to prevent socket leaks
        remoteStateClient.disconnect()
        return .cancel(id: CancelID.connection)

      case .reconnect:
        guard let host = state.selectedHost,
          let saved = state.savedCredentials[host.id]
        else {
          return .none
        }
        state.pinEntry = saved.pin
        state.connectionStatus = .connecting
        return .send(.connectWithPIN)

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
          return .cancel(id: CancelID.connection)
        }

      case .disconnect:
        remoteStateClient.disconnect()
        state.connectionStatus = .disconnected
        state.selectedHost = nil
        return .cancel(id: CancelID.connection)

      case .delegate:
        return .none

      case .binding:
        return .none
      }
    }
  }
}
