import Alfred
import AppKit
import Foundation
import Sparkle

let globalConfigFilename = "config.json"
let workflowConfigFilename = "extra-pane-config.json"

class AppDelegate: NSObject, NSApplicationDelegate {
  let fs = FileManager.default
  var panes: [Pane] = []
  private let defaultConfig = PaneConfig(
    alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
    customUserAgent: nil
  )
  var statusItem: NSStatusItem?
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )

  override init() {
    super.init()
    let confs = globalConfigs() + workflowConfigs()
    dump(confs)
    panes = confs.map { Pane(workflowPaneConfig: $0) }
    Alfred.onItemSelect { item in
      // First, render panes that have exact match with workflowUID.
      // Then, if no exact match is found, render the wildcard panes.
      [
        self.panes.filter({ $0.matchesExactly(item: item) }),
        self.panes.filter({ $0.isGlobal })
      ] .first(where: { !$0.isEmpty })?
        .forEach({ pane in item.quicklookurl.map { pane.render($0) } })
    }
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

  func globalConfigFile() throws -> URL {
    let conf = try! appPrefsDir().appendingPathComponent(globalConfigFilename)
    if !fs.fileExists(atPath: conf.path) {
      write([defaultConfig], to: conf)
    }
    return conf
  }

  func globalConfigs() -> [WorkflowPaneConfig] {
    ((try? read(contentsOf: globalConfigFile())) ?? [defaultConfig])
      .map { WorkflowPaneConfig(paneConfig: $0, workflowUID: nil) }
  }

  func workflowConfigs() -> [WorkflowPaneConfig] {
    Alfred.workflows().flatMap { wf in
      let confPath = wf.dir.appendingPathComponent(workflowConfigFilename)
      let confs: [PaneConfig] = read(contentsOf: confPath) ?? []
      return confs.map {
        WorkflowPaneConfig(paneConfig: $0, workflowUID: wf.uid)
      }
    }
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
