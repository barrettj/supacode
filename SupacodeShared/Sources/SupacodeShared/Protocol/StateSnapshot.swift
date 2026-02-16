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
  public var worktree: RemoteWorktree
  public var tabs: [RemoteTab]
  public var selectedTabID: String?
  public var splitTrees: [String: RemoteSplitTree]
  public var focusedSurfaceByTab: [String: String]
  public var notifications: [RemoteNotification]
  public var taskStatus: RemoteTaskStatus
  public var isRunScriptRunning: Bool
  public var hasUnseenNotifications: Bool
  public var surfaces: [String: RemoteSurface]

  public init(
    worktree: RemoteWorktree,
    tabs: [RemoteTab],
    selectedTabID: String?,
    splitTrees: [String: RemoteSplitTree],
    focusedSurfaceByTab: [String: String],
    notifications: [RemoteNotification],
    taskStatus: RemoteTaskStatus,
    isRunScriptRunning: Bool,
    hasUnseenNotifications: Bool,
    surfaces: [String: RemoteSurface] = [:]
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
    self.surfaces = surfaces
  }
}
