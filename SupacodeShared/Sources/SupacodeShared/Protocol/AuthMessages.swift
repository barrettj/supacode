// Created by Barrett Jacobsen

public struct AuthChallenge: Codable, Sendable, Equatable {
  public let nonce: String

  public init(nonce: String) {
    self.nonce = nonce
  }
}

public struct AuthRequest: Codable, Sendable, Equatable {
  public let hash: String
  public let deviceName: String
  public let sessionToken: String?

  public init(hash: String, deviceName: String, sessionToken: String?) {
    self.hash = hash
    self.deviceName = deviceName
    self.sessionToken = sessionToken
  }
}

public struct AuthResponse: Codable, Sendable, Equatable {
  public let success: Bool
  public let sessionToken: String?
  public let error: String?

  public init(success: Bool, sessionToken: String?, error: String?) {
    self.success = success
    self.sessionToken = sessionToken
    self.error = error
  }
}
