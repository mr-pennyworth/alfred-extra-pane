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
    "vertical" : {"placement" : "top", "height" : 100, "width": 25}},
  "customJSFilename": "script.js",
  "mediaAutoplay": true
}, {
  "alignment" : {
    "vertical" : {"placement" : "bottom", "height" : 200}},
  "staticPaneConfig": {
    "initURL": "https://example.com",
    "function": "render"
  }
}]
""".data(using: .utf8)!

    let expected: [AlfredExtraPane.PaneConfig] = [
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
        customUserAgent: "agent of S.H.I.E.L.D.",
        customCSSFilename: nil,
        customJSFilename: nil,
        staticPaneConfig: nil,
        mediaAutoplay: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .horizontal(placement: .left, width: 300, minHeight: nil),
        customUserAgent: nil,
        customCSSFilename: "style.css",
        customJSFilename: nil,
        staticPaneConfig: nil,
        mediaAutoplay: nil
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .top, height: 100, width: 25),
        customUserAgent: nil,
        customCSSFilename: nil,
        customJSFilename: "script.js",
        staticPaneConfig: nil,
        mediaAutoplay: true
      ),
      AlfredExtraPane.PaneConfig(
        alignment: .vertical(placement: .bottom, height: 200, width: nil),
        customUserAgent: nil,
        customCSSFilename: nil,
        customJSFilename: nil,
        staticPaneConfig: StaticPaneConfig(
          initURL: URL(string: "https://example.com")!,
          function: "render"
        ),
        mediaAutoplay: nil
      )
    ]
    let decoded = try! JSONDecoder().decode(
      [AlfredExtraPane.PaneConfig].self,
      from: confData
    )

    XCTAssertEqual(expected, decoded)
  }
}
