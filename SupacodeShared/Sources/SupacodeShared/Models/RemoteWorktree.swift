// Created by Barrett Jacobsen

public struct RemoteWorktree: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let detail: String
  public let repositoryID: String
  public let isPinned: Bool
  public let isMainWorktree: Bool
  public let addedLines: Int?
  public let removedLines: Int?
  public let pullRequestNumber: Int?
  public let pullRequestState: String?

  public init(
    id: String,
    name: String,
    detail: String,
    repositoryID: String,
    isPinned: Bool = false,
    isMainWorktree: Bool = false,
    addedLines: Int? = nil,
    removedLines: Int? = nil,
    pullRequestNumber: Int? = nil,
    pullRequestState: String? = nil
  ) {
    self.id = id
    self.name = name
    self.detail = detail
    self.repositoryID = repositoryID
    self.isPinned = isPinned
    self.isMainWorktree = isMainWorktree
    self.addedLines = addedLines
    self.removedLines = removedLines
    self.pullRequestNumber = pullRequestNumber
    self.pullRequestState = pullRequestState
  }
}
