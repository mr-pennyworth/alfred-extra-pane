import XCTest
@testable import AlfredExtraPane

final class AlfredExtraPaneTests: XCTestCase {
  func testConfigDeserialization() throws {
    let confData = """
[{
  "customUserAgent": "agent of S.H.I.E.L.D.",
  "alignment" : {
    "horizontal" : {"placement" : "right", "width" : 300, "minHeight" : 400}}
}, {
  "customCSSFilename": "style.css",
  "alignment" : {
    "horizontal" : {"placement" : "left", "width" : 300, "minHeight" : null}}
}, {
  "alignment" : {
    "vertical" : {"placement" : "top", "height" : 100}}
}, {
  "alignment" : {
    "vertical" : {"placement" : "bottom", "height" : 200}}
}]
""".data(using: .utf8)!

    let expected: [AlfredExtraPane.PaneConfig] = [
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
        customUserAgent: "agent of S.H.I.E.L.D.",
        customCSSFilename: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .left, width: 300, minHeight: nil),
        customUserAgent: nil,
        customCSSFilename: "style.css"
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .top, height: 100),
        customUserAgent: nil,
        customCSSFilename: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .bottom, height: 200),
        customUserAgent: nil,
        customCSSFilename: nil
      )
    ]
    let decoded = try! JSONDecoder().decode(
      [AlfredExtraPane.PaneConfig].self,
      from: confData
    )

    XCTAssertEqual(expected, decoded)
  }
}
