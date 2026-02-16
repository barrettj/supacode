// Created by Barrett Jacobsen

public struct RemoteSurface: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let title: String?
  public let pwd: String?
  public let bellCount: Int

  public init(id: String, title: String?, pwd: String?, bellCount: Int) {
    self.id = id
    self.title = title
    self.pwd = pwd
    self.bellCount = bellCount
  }
}
