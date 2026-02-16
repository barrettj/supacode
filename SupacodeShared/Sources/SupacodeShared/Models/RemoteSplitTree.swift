// Created by Barrett Jacobsen

public struct RemoteSplitTree: Codable, Sendable, Equatable {
  public let root: Node?

  public init(root: Node?) {
    self.root = root
  }

  public indirect enum Node: Codable, Sendable, Equatable {
    case leaf(surfaceID: String)
    case split(Split)
  }

  public struct Split: Codable, Sendable, Equatable {
    public let direction: Direction
    public let ratio: Double
    public let left: Node
    public let right: Node

    public init(direction: Direction, ratio: Double, left: Node, right: Node) {
      self.direction = direction
      self.ratio = ratio
      self.left = left
      self.right = right
    }
  }

  public enum Direction: String, Codable, Sendable, Equatable {
    case horizontal
    case vertical
  }
}
