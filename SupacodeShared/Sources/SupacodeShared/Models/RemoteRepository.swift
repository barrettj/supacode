// Created by Barrett Jacobsen

public struct RemoteRepository: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let worktreeIDs: [String]

  public init(id: String, name: String, worktreeIDs: [String]) {
    self.id = id
    self.name = name
    self.worktreeIDs = worktreeIDs
  }
}
