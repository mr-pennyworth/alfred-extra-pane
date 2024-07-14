import Alfred
import AppKit
import Foundation
import Sparkle

let globalConfigFilename = "config.json"
let workflowConfigFilename = "extra-pane-config.json"
let fs = FileManager.default

public let appPrefsDir: URL = {
  let bundleID = Bundle.main.bundleIdentifier ?? "mr.pennyworth.AlfredExtraPane"
  let prefsDir = Alfred
    .prefsDir
    .appendingPathComponent("preferences")
    .appendingPathComponent(bundleID)

  if !fs.fileExists(atPath: prefsDir.path) {
    try? fs.createDirectory(
      at: prefsDir,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  return prefsDir
}()

let globalConfigFile: URL = {
  let conf = appPrefsDir.appendingPathComponent(globalConfigFilename)
  let defaultConfig = PaneConfig(
    alignment: .horizontal(placement: .right, width: 300, minHeight: 400),
    customUserAgent: nil,
    customCSSFilename: nil,
    customJSFilename: nil,
    staticPaneConfig: nil
  )
  if !fs.fileExists(atPath: conf.path) {
    write([defaultConfig], to: conf)
  }
  return conf
}()

let globalConfigs: [WorkflowPaneConfig] = {
  (read(contentsOf: globalConfigFile) ?? [])
    .map { WorkflowPaneConfig(paneConfig: $0, workflowUID: nil) }
}()

let workflowConfigs: [WorkflowPaneConfig] = {
  Alfred.workflows().flatMap { wf in
    let confPath = wf.dir.appendingPathComponent(workflowConfigFilename)
    let confs: [PaneConfig] = read(contentsOf: confPath) ?? []
    return confs.map {
      WorkflowPaneConfig(paneConfig: $0, workflowUID: wf.uid)
    }
  }
}()


class AppDelegate: NSObject, NSApplicationDelegate {
  var panes: [Pane] = []
  var statusItem: NSStatusItem?
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )

  override init() {
    super.init()
    let confs = globalConfigs + workflowConfigs
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
}

autoreleasepool {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  log("\(delegate.panes)")
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
