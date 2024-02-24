import Alfred
import AppKit
import Foundation


class AppDelegate: NSObject, NSApplicationDelegate {
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

  func appSupportDir() throws -> URL {
    let fs = FileManager.default
    let appSupportURL = try fs.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    let bundleID = Bundle.main.bundleIdentifier!
    let appDir = appSupportURL.appendingPathComponent(bundleID)

    if !fs.fileExists(atPath: appDir.path) {
      try fs.createDirectory(
        at: appDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return appDir
  }

  func configFile() throws -> URL {
    let fs = FileManager.default
    let conf = try! appSupportDir().appendingPathComponent("config.json")
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
