// Created by Barrett Jacobsen

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

  @Test func redForeground() {
    let result = ANSIParser.parse("\u{1b}[31mRed\u{1b}[0m")
    #expect(String(result.characters) == "Red")
  }

  @Test func combinedBoldRed() {
    let result = ANSIParser.parse("\u{1b}[1;31mBold Red\u{1b}[0m")
    #expect(String(result.characters) == "Bold Red")
  }

  @Test func color256() {
    let result = ANSIParser.parse("\u{1b}[38;5;196mColor\u{1b}[0m")
    #expect(String(result.characters) == "Color")
  }

  @Test func trueColor() {
    let result = ANSIParser.parse("\u{1b}[38;2;255;128;0mTruecolor\u{1b}[0m")
    #expect(String(result.characters) == "Truecolor")
  }

  @Test func resetClearsAttributes() {
    let result = ANSIParser.parse("\u{1b}[1;31mStyled\u{1b}[0mPlain")
    #expect(String(result.characters) == "StyledPlain")
  }

  @Test func nestedSequences() {
    let result = ANSIParser.parse("\u{1b}[1mBold\u{1b}[31m Red\u{1b}[0m Normal")
    #expect(String(result.characters) == "Bold Red Normal")
  }

  @Test func emptyInput() {
    let result = ANSIParser.parse("")
    #expect(String(result.characters) == "")
  }
}
