// Created by Barrett Jacobsen

import SwiftUI

struct ANSITextView: View {
  let lines: [String]
  let rows: Int
  let cols: Int

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
            Text(ANSIParser.parse(line))
              .font(.system(.body, design: .monospaced))
              .id(index)
          }
        }
        .padding(.horizontal, 8)
      }
    }
    .background(Color.black)
  }
}
