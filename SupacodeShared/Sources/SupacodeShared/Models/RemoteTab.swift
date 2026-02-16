// Created by Barrett Jacobsen

public struct RemoteTab: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let title: String
  public let icon: String?
  public let isDirty: Bool

  public init(id: String, title: String, icon: String?, isDirty: Bool) {
    self.id = id
    self.title = title
    self.icon = icon
    self.isDirty = isDirty
  }
}
