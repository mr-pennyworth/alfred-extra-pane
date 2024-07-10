import XCTest
@testable import AlfredExtraPane

final class AlfredExtraPaneTests: XCTestCase {
  func testConfigDeserialization() throws {
    let confData = """
[{
  "workflowUID" : "mr.pennyworth.BetterDictionaries",
  "customUserAgent": "agent of S.H.I.E.L.D.",
  "alignment" : {
    "horizontal" : {"placement" : "right", "width" : 300, "minHeight" : 400}}
}, {
  "workflowUID" : "*",
  "alignment" : {
    "horizontal" : {"placement" : "left", "width" : 300, "minHeight" : null}}
}, {
  "workflowUID" : "foo.bar",
  "alignment" : {
    "vertical" : {"placement" : "top", "height" : 100}}
}, {
  "workflowUID" : "*",
  "alignment" : {
    "vertical" : {"placement" : "bottom", "height" : 200}}
}]
""".data(using: .utf8)!

    let expected: [AlfredExtraPane.PaneConfig] = [
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
        workflowUID: "mr.pennyworth.BetterDictionaries",
        customUserAgent: "agent of S.H.I.E.L.D."
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .left, width: 300, minHeight: nil),
        workflowUID: "*",
        customUserAgent: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .top, height: 100),
        workflowUID: "foo.bar",
        customUserAgent: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .bottom, height: 200),
        workflowUID: "*",
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
