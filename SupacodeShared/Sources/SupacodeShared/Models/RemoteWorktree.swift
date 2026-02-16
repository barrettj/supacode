// Created by Barrett Jacobsen

public struct RemoteWorktree: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let detail: String
  public let repositoryID: String

  public init(id: String, name: String, detail: String, repositoryID: String) {
    self.id = id
    self.name = name
    self.detail = detail
    self.repositoryID = repositoryID
  }
}
