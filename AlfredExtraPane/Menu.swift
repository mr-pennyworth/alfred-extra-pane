import Alfred
import AppKit
import Foundation

extension AppDelegate {
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

    // Menu for configuring panes
    let configureMenu = NSMenu()
    let globalConfigMenuItem = NSMenuItem(
      title: "Global",
      action: #selector(openFileAction(_:)),
      keyEquivalent: ""
    )
    globalConfigMenuItem.representedObject = globalConfigFile
    configureMenu.addItem(globalConfigMenuItem)
    configureMenu.addItem(NSMenuItem.separator())
    for workflow in Alfred.workflows().sorted(by: {$0.name < $1.name}) {
      let menuItem = NSMenuItem(
        title: workflow.name,
        action: #selector(openFileAction(_:)),
        keyEquivalent: ""
      )
      menuItem.representedObject =
        workflow.dir.appendingPathComponent(workflowConfigFilename)
      configureMenu.addItem(menuItem)
    }
    let configureMenuItem = NSMenuItem(
        title: "Configure",
        action: nil,
        keyEquivalent: ""
    )
    configureMenuItem.submenu = configureMenu
    menu.addItem(configureMenuItem)

    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(
      title: "Check for Updates",
      action: #selector(checkForUpdates),
      keyEquivalent: ""
    ))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(
      title: "Restart " + appName,
      action: #selector(restart),
      keyEquivalent: ""
    ))
    menu.addItem(NSMenuItem(
      title: "Quit " + appName,
      action: #selector(quit),
      keyEquivalent: "q"
    ))

    statusItem?.menu = menu
  }

  @objc func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }

  @objc func restart() {
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-n", Bundle.main.bundlePath]
    task.launch()
    NSApplication.shared.terminate(nil)
  }

  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }

  @objc func openFileAction(_ sender: NSMenuItem) {
    if let filePath = sender.representedObject as? URL {
      if !fs.fileExists(atPath: filePath.path) {
        let empty: [PaneConfig] = []
        write(empty, to: filePath)
      }
      openFile(atPath: filePath.path)
    }
  }
}
