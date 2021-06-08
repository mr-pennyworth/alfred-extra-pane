import Alfred
import AppKit
import Foundation


class AppDelegate: NSObject, NSApplicationDelegate {
  let panes: [Pane]
  let defaultConfig: PaneConfig = PaneConfig(
    alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
    workflowUID: "*"
  )

  init(_ configFilePath: URL?) {
    var configs: [PaneConfig] = []
    if let configFilePath = configFilePath {
      configs = read(contentsOf: configFilePath) ?? []
    }
    if configs.isEmpty {
      log("Loading default catchall-config")
      configs = [defaultConfig]
    }
    panes = configs.map { Pane(config: $0) }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      log("\(url)")
      log("\(url.queryParameters)")
    }
  }
}

autoreleasepool {
  let app = NSApplication.shared
  var configFilePath: URL? = nil
  if let configPath: String = CommandLine.arguments.suffix(from: 1).first {
    configFilePath = URL(fileURLWithPath: configPath)
  } else {
    log("No config file path provided.")
  }
  let delegate = AppDelegate(configFilePath)
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
