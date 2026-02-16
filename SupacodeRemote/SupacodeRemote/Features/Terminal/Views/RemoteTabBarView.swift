// Created by Barrett Jacobsen

import SupacodeShared
import SwiftUI

struct RemoteTabBarView: View {
  let tabs: [RemoteTab]
  let selectedTabID: String?
  let onSelect: (String) -> Void
  let onCreate: () -> Void
  let onClose: (String) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        ForEach(tabs) { tab in
          Button { onSelect(tab.id) } label: {
            HStack(spacing: 4) {
              if let icon = tab.icon {
                Image(systemName: icon)
              }
              Text(tab.title)
                .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tab.id == selectedTabID ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .contextMenu {
            Button("Close Tab", role: .destructive) { onClose(tab.id) }
          }
        }

        Button { onCreate() } label: {
          Image(systemName: "plus")
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal)
    }
    .frame(height: 36)
  }
}
