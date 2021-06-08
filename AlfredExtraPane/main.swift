import Alfred
import AppKit
import Foundation


class AppDelegate: NSObject, NSApplicationDelegate {
  let pane = Pane(
    config: PaneConfig(
      alignment: .horizontal(placement: .right, width: 300, minHeight: 500),
      workflowUID: "*"
    )
  )

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      log("\(url)")
      log("\(url.queryParameters)")
    }
  }
}

autoreleasepool {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
