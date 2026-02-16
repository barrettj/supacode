// Created by Barrett Jacobsen

import SwiftUI

enum ANSIParser {
  static func parse(_ input: String) -> AttributedString {
    var result = AttributedString()
    var currentAttributes = ANSIAttributes()
    var index = input.startIndex

    while index < input.endIndex {
      if input[index] == "\u{1b}",
        input.index(after: index) < input.endIndex,
        input[input.index(after: index)] == "["
      {
        // Parse CSI sequence
        let seqStart = input.index(index, offsetBy: 2)
        if let (params, endIndex) = parseCSISequence(input, from: seqStart) {
          applySGRParams(params, to: &currentAttributes)
          index = input.index(after: endIndex)
        } else {
          // Malformed sequence, treat as text
          var chunk = AttributedString(String(input[index]))
          applyAttributes(&chunk, attributes: currentAttributes)
          result.append(chunk)
          index = input.index(after: index)
        }
      } else {
        // Regular character — collect run of non-escape chars
        let runStart = index
        while index < input.endIndex && input[index] != "\u{1b}" {
          index = input.index(after: index)
        }
        var chunk = AttributedString(String(input[runStart..<index]))
        applyAttributes(&chunk, attributes: currentAttributes)
        result.append(chunk)
      }
    }
    return result
  }

  // MARK: - CSI Sequence Parsing

  /// Parses a CSI parameter sequence starting after `\e[`, returning the semicolon-separated
  /// integer parameters and the index of the terminating `m` character.
  private static func parseCSISequence(
    _ input: String,
    from start: String.Index
  ) -> (params: [Int], endIndex: String.Index)? {
    var index = start
    var paramString = ""

    while index < input.endIndex {
      let char = input[index]
      if char == "m" {
        let params = paramString.isEmpty
          ? [0]
          : paramString.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        return (params, index)
      } else if char.isASCII && (char.isNumber || char == ";") {
        paramString.append(char)
        index = input.index(after: index)
      } else {
        // Non-SGR CSI sequence or malformed
        return nil
      }
    }
    return nil
  }

  // MARK: - SGR Parameter Application

  private static func applySGRParams(_ params: [Int], to attributes: inout ANSIAttributes) {
    var i = 0
    while i < params.count {
      let code = params[i]
      switch code {
      case 0:
        attributes = ANSIAttributes()
      case 1:
        attributes.bold = true
      case 2:
        attributes.dim = true
      case 3:
        attributes.italic = true
      case 4:
        attributes.underline = true
      case 9:
        attributes.strikethrough = true
      case 22:
        attributes.bold = false
        attributes.dim = false
      case 23:
        attributes.italic = false
      case 24:
        attributes.underline = false
      case 29:
        attributes.strikethrough = false
      case 30...37:
        attributes.foregroundColor = standardColor(code - 30)
      case 38:
        if let (color, advance) = parseExtendedColor(params, startingAt: i) {
          attributes.foregroundColor = color
          i += advance
        }
      case 39:
        attributes.foregroundColor = nil
      case 40...47:
        attributes.backgroundColor = standardColor(code - 40)
      case 48:
        if let (color, advance) = parseExtendedColor(params, startingAt: i) {
          attributes.backgroundColor = color
          i += advance
        }
      case 49:
        attributes.backgroundColor = nil
      case 90...97:
        attributes.foregroundColor = brightColor(code - 90)
      case 100...107:
        attributes.backgroundColor = brightColor(code - 100)
      default:
        break
      }
      i += 1
    }
  }

  // MARK: - Extended Color Parsing

  /// Parses 256-color (`5;N`) or truecolor (`2;R;G;B`) sequences starting at the given index.
  /// Returns the parsed color and the number of additional parameters consumed.
  private static func parseExtendedColor(_ params: [Int], startingAt index: Int) -> (Color, Int)? {
    guard index + 1 < params.count else { return nil }

    switch params[index + 1] {
    case 5:
      // 256-color mode: 38;5;N or 48;5;N
      guard index + 2 < params.count else { return nil }
      let colorIndex = params[index + 2]
      return (color256(colorIndex), 2)
    case 2:
      // Truecolor mode: 38;2;R;G;B or 48;2;R;G;B
      guard index + 4 < params.count else { return nil }
      let r = Double(params[index + 2]) / 255.0
      let g = Double(params[index + 3]) / 255.0
      let b = Double(params[index + 4]) / 255.0
      return (Color(red: r, green: g, blue: b), 4)
    default:
      return nil
    }
  }

  // MARK: - Attribute Application

  private static func applyAttributes(_ string: inout AttributedString, attributes: ANSIAttributes) {
    if attributes.bold {
      string.font = .body.monospaced().bold()
    } else if attributes.dim {
      string.font = .body.monospaced().weight(.light)
    } else {
      string.font = .body.monospaced()
    }

    if attributes.italic {
      string.font = (string.font ?? .body.monospaced()).italic()
    }

    string.underlineStyle = attributes.underline ? .single : nil
    string.strikethroughStyle = attributes.strikethrough ? .single : nil

    if let fg = attributes.foregroundColor {
      string.foregroundColor = fg
    }

    if let bg = attributes.backgroundColor {
      string.backgroundColor = bg
    }
  }

  // MARK: - Standard Colors

  private static func standardColor(_ index: Int) -> Color {
    switch index {
    case 0: return Color.black
    case 1: return Color.red
    case 2: return Color.green
    case 3: return Color.yellow
    case 4: return Color.blue
    case 5: return Color.purple
    case 6: return Color.cyan
    case 7: return Color.white
    default: return Color.primary
    }
  }

  private static func brightColor(_ index: Int) -> Color {
    switch index {
    case 0: return Color.gray
    case 1: return Color.red.opacity(0.8)
    case 2: return Color.green.opacity(0.8)
    case 3: return Color.yellow.opacity(0.8)
    case 4: return Color.blue.opacity(0.8)
    case 5: return Color.purple.opacity(0.8)
    case 6: return Color.cyan.opacity(0.8)
    case 7: return Color.white
    default: return Color.primary
    }
  }

  // MARK: - 256-Color Lookup

  private static func color256(_ index: Int) -> Color {
    switch index {
    case 0...7:
      return standardColor(index)
    case 8...15:
      return brightColor(index - 8)
    case 16...231:
      // 216-color cube: 6x6x6
      let adjusted = index - 16
      let r = adjusted / 36
      let g = (adjusted % 36) / 6
      let b = adjusted % 6
      return Color(
        red: r == 0 ? 0 : (Double(r) * 40 + 55) / 255.0,
        green: g == 0 ? 0 : (Double(g) * 40 + 55) / 255.0,
        blue: b == 0 ? 0 : (Double(b) * 40 + 55) / 255.0
      )
    case 232...255:
      // Grayscale ramp: 24 shades
      let level = Double(index - 232) * 10 + 8
      let value = level / 255.0
      return Color(red: value, green: value, blue: value)
    default:
      return Color.primary
    }
  }
}

// MARK: - ANSIAttributes

private struct ANSIAttributes {
  var bold = false
  var dim = false
  var italic = false
  var underline = false
  var strikethrough = false
  var foregroundColor: Color?
  var backgroundColor: Color?
}
