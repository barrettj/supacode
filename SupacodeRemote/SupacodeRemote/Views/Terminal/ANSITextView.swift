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
              .font(.body.monospaced())
              .id(index)
              .accessibilityLabel(ANSIParser.stripANSI(line))
          }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal output")
      }
    }
    .background(.background)
  }
}
