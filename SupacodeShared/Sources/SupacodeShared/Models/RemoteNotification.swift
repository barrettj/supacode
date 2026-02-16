// Created by Barrett Jacobsen

public struct RemoteNotification: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let surfaceID: String
  public let title: String
  public let body: String
  public let isRead: Bool

  public init(id: String, surfaceID: String, title: String, body: String, isRead: Bool) {
    self.id = id
    self.surfaceID = surfaceID
    self.title = title
    self.body = body
    self.isRead = isRead
  }
}
