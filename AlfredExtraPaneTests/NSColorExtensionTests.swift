import XCTest
@testable import AlfredExtraPane

class NSColorExtensionTests: XCTestCase {
  
  struct ColorTestCase {
    let hex: String
    let expectedColor: NSColor?
  }
  
  func testHexColors() {
    let testCases: [ColorTestCase] = [
      ColorTestCase(hex: "#FF0000FF", expectedColor: NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)),
      ColorTestCase(hex: "0x00FF00FF", expectedColor: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)),
      ColorTestCase(hex: "0000FFFF", expectedColor: NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)),
      ColorTestCase(hex: "#123456", expectedColor: NSColor(red: 18/255.0, green: 52/255.0, blue: 86/255.0, alpha: 0.0)),
      ColorTestCase(hex: "#GGGGGG", expectedColor: nil),
      ColorTestCase(hex: "#12345", expectedColor: nil),
      ColorTestCase(hex: "  #FFFFFF  ", expectedColor: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0))
    ]
    
    for testCase in testCases {
      let color = NSColor.from(hex: testCase.hex)
      if let expectedColor = testCase.expectedColor {
        XCTAssertNotNil(color, "Expected color to be non-nil for hex \(testCase.hex)")
        XCTAssertEqual(color, expectedColor, "Color mismatch for hex \(testCase.hex)")
      } else {
        XCTAssertNil(color, "Expected color to be nil for hex \(testCase.hex)")
      }
    }
  }
}

