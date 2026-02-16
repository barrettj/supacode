// Created by Barrett Jacobsen

import Foundation
import Testing

@testable import SupacodeShared

@Suite("Remote Models Round-Trip Encoding")
struct ModelsTests {

  private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(value)
    return try JSONDecoder().decode(T.self, from: data)
  }

  // MARK: - RemoteRepository

  @Test func repositoryRoundTrip() throws {
    let repo = RemoteRepository(
      id: "repo-1",
      name: "my-project",
      worktreeIDs: ["wt-1", "wt-2", "wt-3"]
    )
    let decoded = try roundTrip(repo)
    #expect(decoded == repo)
  }

  @Test func repositoryEmptyWorktrees() throws {
    let repo = RemoteRepository(
      id: "repo-2",
      name: "empty-project",
      worktreeIDs: []
    )
    let decoded = try roundTrip(repo)
    #expect(decoded == repo)
  }

  // MARK: - RemoteWorktree

  @Test func worktreeRoundTrip() throws {
    let worktree = RemoteWorktree(
      id: "wt-1",
      name: "feature-branch",
      detail: "feature/add-login",
      repositoryID: "repo-1"
    )
    let decoded = try roundTrip(worktree)
    #expect(decoded == worktree)
  }

  // MARK: - RemoteTab

  @Test func tabRoundTrip() throws {
    let tab = RemoteTab(
      id: "tab-1",
      title: "Terminal 1",
      icon: "terminal",
      isDirty: true
    )
    let decoded = try roundTrip(tab)
    #expect(decoded == tab)
  }

  @Test func tabNilIcon() throws {
    let tab = RemoteTab(
      id: "tab-2",
      title: "Terminal 2",
      icon: nil,
      isDirty: false
    )
    let decoded = try roundTrip(tab)
    #expect(decoded == tab)
    #expect(decoded.icon == nil)
  }

  // MARK: - RemoteSurface

  @Test func surfaceRoundTrip() throws {
    let surface = RemoteSurface(
      id: "surface-1",
      title: "zsh",
      pwd: "/Users/test/project",
      bellCount: 3
    )
    let decoded = try roundTrip(surface)
    #expect(decoded == surface)
  }

  @Test func surfaceNilFields() throws {
    let surface = RemoteSurface(
      id: "surface-2",
      title: nil,
      pwd: nil,
      bellCount: 0
    )
    let decoded = try roundTrip(surface)
    #expect(decoded == surface)
    #expect(decoded.title == nil)
    #expect(decoded.pwd == nil)
  }

  // MARK: - RemoteSplitTree

  @Test func splitTreeNilRoot() throws {
    let tree = RemoteSplitTree(root: nil)
    let decoded = try roundTrip(tree)
    #expect(decoded == tree)
    #expect(decoded.root == nil)
  }

  @Test func splitTreeSingleLeaf() throws {
    let tree = RemoteSplitTree(root: .leaf(surfaceID: "surface-1"))
    let decoded = try roundTrip(tree)
    #expect(decoded == tree)
  }

  @Test func splitTreeSingleSplit() throws {
    let tree = RemoteSplitTree(
      root: .split(
        RemoteSplitTree.Split(
          direction: .horizontal,
          ratio: 0.5,
          left: .leaf(surfaceID: "surface-1"),
          right: .leaf(surfaceID: "surface-2")
        )
      )
    )
    let decoded = try roundTrip(tree)
    #expect(decoded == tree)
  }

  @Test func splitTreeNestedSplits() throws {
    let tree = RemoteSplitTree(
      root: .split(
        RemoteSplitTree.Split(
          direction: .vertical,
          ratio: 0.6,
          left: .split(
            RemoteSplitTree.Split(
              direction: .horizontal,
              ratio: 0.5,
              left: .leaf(surfaceID: "surface-1"),
              right: .leaf(surfaceID: "surface-2")
            )
          ),
          right: .leaf(surfaceID: "surface-3")
        )
      )
    )
    let decoded = try roundTrip(tree)
    #expect(decoded == tree)
  }

  // MARK: - RemoteNotification

  @Test func notificationUnread() throws {
    let notification = RemoteNotification(
      id: "notif-1",
      surfaceID: "surface-1",
      title: "Task Complete",
      body: "Build succeeded",
      isRead: false
    )
    let decoded = try roundTrip(notification)
    #expect(decoded == notification)
    #expect(decoded.isRead == false)
  }

  @Test func notificationRead() throws {
    let notification = RemoteNotification(
      id: "notif-2",
      surfaceID: "surface-2",
      title: "Error",
      body: "Build failed",
      isRead: true
    )
    let decoded = try roundTrip(notification)
    #expect(decoded == notification)
    #expect(decoded.isRead == true)
  }

  // MARK: - RemoteTaskStatus

  @Test func taskStatusIdle() throws {
    let status = RemoteTaskStatus.idle
    let decoded = try roundTrip(status)
    #expect(decoded == status)
  }

  @Test func taskStatusRunning() throws {
    let status = RemoteTaskStatus.running
    let decoded = try roundTrip(status)
    #expect(decoded == status)
  }
}
