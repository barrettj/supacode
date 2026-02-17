// Created by Barrett Jacobsen

import ComposableArchitecture
import Network

private let logger = RemoteLogger("Bonjour")

struct DiscoveredHost: Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  let endpoint: NWEndpoint
}

struct BonjourClient {
  var startDiscovery: @Sendable () -> AsyncStream<[DiscoveredHost]>
  var stopDiscovery: @Sendable () -> Void
}

extension BonjourClient: DependencyKey {
  static let liveValue: BonjourClient = {
    let manager = BonjourManager()
    return BonjourClient(
      startDiscovery: { manager.startDiscovery() },
      stopDiscovery: { manager.stopDiscovery() },
    )
  }()

  static let testValue = BonjourClient(
    startDiscovery: { AsyncStream { $0.finish() } },
    stopDiscovery: {},
  )
}

extension DependencyValues {
  var bonjourClient: BonjourClient {
    get { self[BonjourClient.self] }
    set { self[BonjourClient.self] = newValue }
  }
}

// MARK: - Live Implementation

private final class BonjourManager: Sendable {
  private let browser: NWBrowser
  private let continuation: AsyncStream<[DiscoveredHost]>.Continuation
  private let stream: AsyncStream<[DiscoveredHost]>

  init() {
    let descriptor = NWBrowser.Descriptor.bonjour(type: "_supacode._tcp", domain: nil)
    let parameters = NWParameters()
    parameters.includePeerToPeer = true
    browser = NWBrowser(for: descriptor, using: parameters)

    var storedContinuation: AsyncStream<[DiscoveredHost]>.Continuation!
    stream = AsyncStream { continuation in
      storedContinuation = continuation
    }
    continuation = storedContinuation
  }

  func startDiscovery() -> AsyncStream<[DiscoveredHost]> {
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      guard let self else { return }
      let hosts = results.compactMap { result -> DiscoveredHost? in
        switch result.endpoint {
        case .service(let name, _, _, _):
          return DiscoveredHost(
            id: "\(result.endpoint)",
            name: name,
            endpoint: result.endpoint,
          )
        default:
          return nil
        }
      }
      self.continuation.yield(hosts)
    }

    browser.stateUpdateHandler = { [weak self] state in
      switch state {
      case .failed(let error):
        logger.warning("Bonjour browser failed: \(error)")
      case .cancelled:
        self?.continuation.finish()
      default:
        break
      }
    }

    browser.start(queue: .main)
    return stream
  }

  func stopDiscovery() {
    browser.cancel()
  }
}
