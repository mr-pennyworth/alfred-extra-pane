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
        customUserAgent: "agent of S.H.I.E.L.D."
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .left, width: 300, minHeight: nil),
        customUserAgent: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .top, height: 100),
        customUserAgent: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .bottom, height: 200),
        customUserAgent: nil
      )
    ]
    let decoded = try! JSONDecoder().decode(
      [AlfredExtraPane.PaneConfig].self,
      from: confData
    )

    XCTAssertEqual(expected, decoded)
  }
}
