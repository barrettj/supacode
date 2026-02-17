// Created by Barrett Jacobsen

import SwiftUI
import Testing

@testable import SupacodeRemote

@Suite("ANSIParser")
struct ANSIParserTests {
  @Test func plainText() {
    let result = ANSIParser.parse("Hello, World!")
    #expect(String(result.characters) == "Hello, World!")
  }

  @Test func boldText() {
    let result = ANSIParser.parse("\u{1b}[1mBold\u{1b}[0m Normal")
    #expect(String(result.characters) == "Bold Normal")
  }

  @Test func boldTextHasAttribute() {
    let result = ANSIParser.parse("\u{1b}[1mBold\u{1b}[0m")
    let boldRange = result.range(of: "Bold")!
    let font = result[boldRange].font
    #expect(font != nil)
  }

  @Test func redForeground() {
    let result = ANSIParser.parse("\u{1b}[31mRed\u{1b}[0m")
    #expect(String(result.characters) == "Red")
  }

  @Test func redForegroundHasColor() {
    let result = ANSIParser.parse("\u{1b}[31mRed\u{1b}[0m")
    let range = result.range(of: "Red")!
    #expect(result[range].foregroundColor != nil)
  }

  @Test func combinedBoldRed() {
    let result = ANSIParser.parse("\u{1b}[1;31mBold Red\u{1b}[0m")
    #expect(String(result.characters) == "Bold Red")
  }

  @Test func combinedBoldRedHasAttributes() {
    let result = ANSIParser.parse("\u{1b}[1;31mBold Red\u{1b}[0m")
    let range = result.range(of: "Bold Red")!
    #expect(result[range].font != nil)
    #expect(result[range].foregroundColor != nil)
  }

  @Test func color256() {
    let result = ANSIParser.parse("\u{1b}[38;5;196mColor\u{1b}[0m")
    #expect(String(result.characters) == "Color")
  }

  @Test func color256HasColor() {
    let result = ANSIParser.parse("\u{1b}[38;5;196mColor\u{1b}[0m")
    let range = result.range(of: "Color")!
    #expect(result[range].foregroundColor != nil)
  }

  @Test func trueColor() {
    let result = ANSIParser.parse("\u{1b}[38;2;255;128;0mTruecolor\u{1b}[0m")
    #expect(String(result.characters) == "Truecolor")
  }

  @Test func trueColorHasColor() {
    let result = ANSIParser.parse("\u{1b}[38;2;255;128;0mTruecolor\u{1b}[0m")
    let range = result.range(of: "Truecolor")!
    #expect(result[range].foregroundColor != nil)
  }

  @Test func resetClearsAttributes() {
    let result = ANSIParser.parse("\u{1b}[1;31mStyled\u{1b}[0mPlain")
    #expect(String(result.characters) == "StyledPlain")
  }

  @Test func resetClearsColor() {
    let result = ANSIParser.parse("\u{1b}[31mRed\u{1b}[0mPlain")
    let plainRange = result.range(of: "Plain")!
    #expect(result[plainRange].foregroundColor == nil)
  }

  @Test func underlineAttribute() {
    let result = ANSIParser.parse("\u{1b}[4mUnderlined\u{1b}[0m")
    #expect(String(result.characters) == "Underlined")
    let range = result.range(of: "Underlined")!
    #expect(result[range].underlineStyle == .single)
  }

  @Test func strikethroughAttribute() {
    let result = ANSIParser.parse("\u{1b}[9mStruck\u{1b}[0m")
    #expect(String(result.characters) == "Struck")
    let range = result.range(of: "Struck")!
    #expect(result[range].strikethroughStyle == .single)
  }

  @Test func backgroundColorAttribute() {
    let result = ANSIParser.parse("\u{1b}[42mGreen BG\u{1b}[0m")
    #expect(String(result.characters) == "Green BG")
    let range = result.range(of: "Green BG")!
    #expect(result[range].backgroundColor != nil)
  }

  @Test func nestedSequences() {
    let result = ANSIParser.parse("\u{1b}[1mBold\u{1b}[31m Red\u{1b}[0m Normal")
    #expect(String(result.characters) == "Bold Red Normal")
  }

  @Test func nestedSequencesAttributes() {
    let result = ANSIParser.parse("\u{1b}[1mBold\u{1b}[31m Red\u{1b}[0m Normal")
    let normalRange = result.range(of: " Normal")!
    #expect(result[normalRange].foregroundColor == nil)
  }

  @Test func emptyInput() {
    let result = ANSIParser.parse("")
    #expect(String(result.characters) == "")
  }

  @Test func stripANSI() {
    let result = ANSIParser.stripANSI("\u{1b}[1;31mBold Red\u{1b}[0m Normal")
    #expect(result == "Bold Red Normal")
  }
}
