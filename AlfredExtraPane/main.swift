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
    } else {
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
  let args = CommandLine.arguments.suffix(from: 1)
  var configFilePath: URL? = nil
  if let configPath: String = args.first {
    if FileManager().fileExists(atPath: configPath) {
      configFilePath = URL(fileURLWithPath: configPath)
    }
  }
  if configFilePath == nil {
    log("No config file path provided. args: \(args)")
  }
  let delegate = AppDelegate(configFilePath)
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
