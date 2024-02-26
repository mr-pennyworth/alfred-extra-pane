import Alfred
import AppKit
import Foundation


class AppDelegate: NSObject, NSApplicationDelegate {
  let fs = FileManager.default
  var panes: [Pane] = []
  private let defaultConfig = PaneConfig(
    alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
    workflowUID: "*"
  )

  override init() {
    super.init()
    let confs: [PaneConfig] =
      (try? read(contentsOf: configFile())) ?? [defaultConfig]
    panes = confs.map { Pane(config: $0) }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      log("\(url)")
      log("\(url.queryParameters)")
    }
  }

  func appPrefsDir() throws -> URL {
    let bundleID = Bundle.main.bundleIdentifier!
    let prefsDir = Alfred
      .prefsDir
      .appendingPathComponent("preferences")
      .appendingPathComponent(bundleID)

    if !fs.fileExists(atPath: prefsDir.path) {
      try fs.createDirectory(
        at: prefsDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return prefsDir
  }

  func configFile() throws -> URL {
    let conf = try! appPrefsDir().appendingPathComponent("config.json")
    if !fs.fileExists(atPath: conf.path) {
      write([defaultConfig], to: conf)
    }
    return conf
  }
}

autoreleasepool {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  print("\(delegate.panes)")
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
