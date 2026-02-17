// Created by Barrett Jacobsen

public enum StateDelta: Codable, Sendable, Equatable {
  case repositoriesChanged([RemoteRepository])
  case worktreeAdded(RemoteWorktreeState)
  case worktreeRemoved(worktreeID: String)
  case selectedWorktreeChanged(worktreeID: String?)
  case tabAdded(worktreeID: String, tab: RemoteTab)
  case tabRemoved(worktreeID: String, tabID: String)
  case tabUpdated(worktreeID: String, tabID: String, update: RemoteTabUpdate)
  case selectedTabChanged(worktreeID: String, tabID: String?)
  case splitTreeChanged(worktreeID: String, tabID: String, tree: RemoteSplitTree)
  case surfaceMetadataUpdated(surfaceID: String, update: RemoteSurfaceUpdate)
  case focusChanged(worktreeID: String, tabID: String, surfaceID: String)
  case notificationReceived(worktreeID: String, notification: RemoteNotification)
  case notificationRead(worktreeID: String, notificationID: String)
  case notificationsCleared(worktreeID: String)
  case taskStatusChanged(worktreeID: String, status: RemoteTaskStatus)
  case runScriptStatusChanged(worktreeID: String, isRunning: Bool)
  case repositoryExpandedChanged(repositoryID: String, isExpanded: Bool)
}

public struct RemoteTabUpdate: Codable, Sendable, Equatable {
  public var title: String?
  public var icon: String?
  public var isDirty: Bool?

  public init(title: String? = nil, icon: String? = nil, isDirty: Bool? = nil) {
    self.title = title
    self.icon = icon
    self.isDirty = isDirty
  }
}

public struct RemoteSurfaceUpdate: Codable, Sendable, Equatable {
  public var title: String?
  public var pwd: String?
  public var bellCount: Int?

  public init(title: String? = nil, pwd: String? = nil, bellCount: Int? = nil) {
    self.title = title
    self.pwd = pwd
    self.bellCount = bellCount
  }
}
