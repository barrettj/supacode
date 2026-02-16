// Created by Barrett Jacobsen

public struct StateSnapshot: Codable, Sendable, Equatable {
  public let repositories: [RemoteRepository]
  public let selectedWorktreeID: String?
  public let worktreeStates: [String: RemoteWorktreeState]

  public init(
    repositories: [RemoteRepository],
    selectedWorktreeID: String?,
    worktreeStates: [String: RemoteWorktreeState]
  ) {
    self.repositories = repositories
    self.selectedWorktreeID = selectedWorktreeID
    self.worktreeStates = worktreeStates
  }
}

public struct RemoteWorktreeState: Codable, Sendable, Equatable {
  public let worktree: RemoteWorktree
  public let tabs: [RemoteTab]
  public let selectedTabID: String?
  public let splitTrees: [String: RemoteSplitTree]
  public let focusedSurfaceByTab: [String: String]
  public let notifications: [RemoteNotification]
  public let taskStatus: RemoteTaskStatus
  public let isRunScriptRunning: Bool
  public let hasUnseenNotifications: Bool

  public init(
    worktree: RemoteWorktree,
    tabs: [RemoteTab],
    selectedTabID: String?,
    splitTrees: [String: RemoteSplitTree],
    focusedSurfaceByTab: [String: String],
    notifications: [RemoteNotification],
    taskStatus: RemoteTaskStatus,
    isRunScriptRunning: Bool,
    hasUnseenNotifications: Bool
  ) {
    self.worktree = worktree
    self.tabs = tabs
    self.selectedTabID = selectedTabID
    self.splitTrees = splitTrees
    self.focusedSurfaceByTab = focusedSurfaceByTab
    self.notifications = notifications
    self.taskStatus = taskStatus
    self.isRunScriptRunning = isRunScriptRunning
    self.hasUnseenNotifications = hasUnseenNotifications
  }
}
