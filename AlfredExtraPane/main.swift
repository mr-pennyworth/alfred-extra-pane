import Alfred
import AppKit
import Foundation
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
  let fs = FileManager.default
  var panes: [Pane] = []
  private let defaultConfig = PaneConfig(
    alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
    workflowUID: "*"
  )
  var statusItem: NSStatusItem?
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )

  override init() {
    super.init()
    let confs: [PaneConfig] =
      (try? read(contentsOf: configFile())) ?? [defaultConfig]
    panes = confs.map { Pane(config: $0) }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    setupMenubarExtra()
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

  func setupMenubarExtra() {
    let appName =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    statusItem =
      NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      let image = NSImage(
        systemSymbolName: "sidebar.right",
        accessibilityDescription: appName + " Menu"
      )
      image?.isTemplate = true
      button.image = image
      button.toolTip = appName
    }

    let menu = NSMenu()
    menu.addItem(NSMenuItem(
      title: "Check for Updates",
      action: #selector(checkForUpdates),
      keyEquivalent: "u"
    ))
    menu.addItem(NSMenuItem(
      title: "Restart " + appName,
      action: #selector(restart),
      keyEquivalent: "r"
    ))

    statusItem?.menu = menu
  }

  @objc func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }

  @objc func restart() {
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [Bundle.main.bundlePath]
    task.launch()
    NSApplication.shared.terminate(nil)
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
