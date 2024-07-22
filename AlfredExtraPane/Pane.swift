import Alfred
import Cocoa
import Foundation
import WebKit

enum PanePosition: Equatable {
  enum HorizontalPlacement: String, Codable, CodingKey { case left, right }
  enum VerticalPlacement: String, Codable, CodingKey { case top, bottom }

  case horizontal(placement: HorizontalPlacement, width: Int, minHeight: Int?)
  case vertical(placement: VerticalPlacement, height: Int)
}

public struct WorkflowPaneConfig {
  let paneConfig: PaneConfig
  /// A nil workflowUID means that this pane is a global pane,
  /// applicable to all the workflows.
  let workflowUID: String?

  func dir() -> URL {
    if let uid = workflowUID {
      return Alfred.workflows().first(where: { $0.uid == uid })!.dir
    } else {
      return appPrefsDir
    }
  }
}

/// While a non-static pane renders the URL in Alfred item's `quicklookurl`,
/// a static pane renders the URL in the pane's configuration once, and then uses
/// the `quicklookurl` as a text file containing the input to be passed
/// to the JavaScript `function`.
public struct StaticPaneConfig: Codable, Equatable {
  let initURL: URL
  let function: String
}

public struct PaneConfig: Codable, Equatable {
  let alignment: PanePosition
  let customUserAgent: String?
  let customCSSFilename: String?
  let customJSFilename: String?
  let staticPaneConfig: StaticPaneConfig?
  let mediaAutoplay: Bool?
}

class Pane {
  let workflowUID: String? // nil for global panes
  let config: PaneConfig
  var alfredFrame: NSRect = .zero
  let window: NSWindow = makeWindow()
  let margin: CGFloat = 5

  private lazy var webView: WKWebView = {
    makeWebView(
      WorkflowPaneConfig(paneConfig: config, workflowUID: workflowUID)
    )
  }()

  init(workflowPaneConfig: WorkflowPaneConfig) {
    self.config = workflowPaneConfig.paneConfig
    self.workflowUID = workflowPaneConfig.workflowUID
    window.contentView!.addSubview(webView)

    if let staticConf = self.config.staticPaneConfig {
      webView.load(URLRequest(url: staticConf.initURL))
    }

    Alfred.onHide { self.hide() }
    Alfred.onFrameChange { self.alfredFrame = $0 }
  }

  lazy var isGlobal: Bool = { self.workflowUID == nil }()

  func matchesExactly(item: Alfred.SelectedItem) -> Bool {
    item.workflowuid == self.workflowUID
  }

  func render(_ url: URL) {
    if let staticConf = config.staticPaneConfig {
      if let arg = try? String(contentsOf: url) {
        let safeArg = arg.replacingOccurrences(of: "`", with: "\\`")
        let js = "\(staticConf.function)(`\(safeArg)`)"
        log("evaluating JS: \(js)")
        webView.evaluateJavaScript(js)
      } else {
        log("failed to read '\(url)' as text file")
      }
    } else if url.isFileURL {
      if url.absoluteString.hasSuffix(".html") {
        let dir = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: dir)
      } else {
        log("skipping displaying '\(url)' as it isn't HTML")
        return
      }
    } else {
      webView.load(URLRequest(url: url))
    }
    showWindow()
  }

  func width() -> CGFloat {
    switch self.config.alignment {
    case .horizontal(_, let w, _): return CGFloat(w)
    case .vertical(_, _): return alfredFrame.width
    }
  }

  func height() -> CGFloat {
    switch self.config.alignment {
    case .horizontal(_, _, nil): return alfredFrame.height
    case .horizontal(_, _, let mh?): return max(CGFloat(mh), alfredFrame.height)
    case .vertical(_, let h): return CGFloat(h)
    }
  }

  func x() -> CGFloat {
    let alf = alfredFrame.minX
    let alfw = alfredFrame.width
    switch self.config.alignment {
    case .vertical(_, _): return alf
    case .horizontal(.left, _, _): return alf - (width() + margin)
    case .horizontal(.right, _, _): return alf + (alfw + margin)
    }
  }

  func y() -> CGFloat {
    let alf = alfredFrame
    switch self.config.alignment {
    case .horizontal(_, _, _): return alf.maxY - height()
    case .vertical(.top, _): return alf.maxY + margin
    case .vertical(.bottom, _): return alf.minY - (height() + margin)
    }
  }

  func frame() -> NSRect {
    NSRect(x: x(), y: y(), width: width(), height: height())
  }

  func showWindow() {
    window.setFrame(frame(), display: false)
    webView.setFrameOrigin(NSPoint(x: 0, y: 0))
    webView.setFrameSize(frame().size)
    window.orderFront(self)
  }

  func hide() {
    if !window.isKeyWindow {
      window.orderOut(self)
    }
  }
}

let cornerRadius =
  CGFloat((Alfred.theme["window-roundness"] as? Float) ?? 0)

/// When an NSWindow is created with the borderless style mask, it can not
/// become the key window. We want the extra pane to be borderless, and at
/// the same time, we want the user to be able to click on the window so that
/// it doesn't vanish on Alfred's disappearance.
class ExtraPaneWindow: NSWindow {
  override var canBecomeKey: Bool { true }

  // When the window rendering is triggered due to Alfred's quicklookurl, we
  // display the window, without making it the key window. In this case, the
  // window should hide when Alfred hides. However, if the user clicks on the
  // window, it becomes the key window and the user can interact with it, even
  // after Alfred hides. For such a window, we want it to hide when it loses
  // the focus.
  override func resignKey() {
    super.resignKey()
    self.orderOut(nil)
  }
}

func makeWindow() -> NSWindow {
  let windowColorHex =
    (Alfred.theme["window-color"] as? String) ?? "#1d1e28ff"
  let windowColor = NSColor.from(hex: windowColorHex)!

  let window = ExtraPaneWindow(
    contentRect: .zero,
    styleMask: [.borderless, .fullSizeContentView],
    backing: .buffered,
    defer: false,
    screen: NSScreen.main!
  )
  window.backgroundColor = .clear
  window.level = .floating
  window.collectionBehavior = [
    .canJoinAllSpaces, .stationary, .fullScreenAuxiliary
  ]

  // weird: without the following line
  // the webview just doesn't load!
  window.titlebarAppearsTransparent = true

  let containerView = NSView(frame: window.contentView!.bounds)
  containerView.autoresizingMask = [.width, .height]
  containerView.wantsLayer = true
  containerView.layer?.cornerRadius = cornerRadius
  containerView.layer?.masksToBounds = true
  
  let colorView = NSView(frame: containerView.bounds)
  colorView.autoresizingMask = [.width, .height]
  colorView.wantsLayer = true
  colorView.layer?.backgroundColor = windowColor.cgColor
  colorView.layer?.cornerRadius = cornerRadius
  colorView.layer?.masksToBounds = true

  // Since Alfred has deprecated "Classic Blur", we don't bother
  // supporting it.
  if Alfred.visualEffect == .light || Alfred.visualEffect == .dark {
    let blurView = NSVisualEffectView(frame: containerView.bounds)
    blurView.autoresizingMask = [.width, .height]
    blurView.material = if Alfred.visualEffect == .light {
      .mediumLight
    } else {
      .dark
    }
    blurView.blendingMode = .behindWindow
    blurView.state = .active
    blurView.wantsLayer = true
    blurView.layer?.cornerRadius = cornerRadius
    blurView.layer?.masksToBounds = true

    blurView.addSubview(colorView)
    containerView.addSubview(blurView)
  } else {
    containerView.addSubview(colorView)
  }
  
  window.contentView?.addSubview(containerView)

  return window
}

func makeWebView(_ workflowPaneConfig: WorkflowPaneConfig) -> WKWebView {
  let conf = WKWebViewConfiguration()
  conf.preferences.setValue(true, forKey: "developerExtrasEnabled")

  if workflowPaneConfig.paneConfig.mediaAutoplay != true {
    conf.mediaTypesRequiringUserActionForPlayback = .all
  }

  var cssString = Alfred.themeCSS
  if let wfCSSFilename = workflowPaneConfig.paneConfig.customCSSFilename {
    let wfCSSFile =
      workflowPaneConfig.dir().appendingPathComponent(wfCSSFilename)
    if let wfCSSString = try? String(contentsOf: wfCSSFile) {
      cssString += "\n" + wfCSSString
    } else {
      log("Failed to read custom CSS file: \(wfCSSFile)")
    }
  }

  var jsString = ""
  if let wfJSFilename = workflowPaneConfig.paneConfig.customJSFilename {
    let wfJSFile =
      workflowPaneConfig.dir().appendingPathComponent(wfJSFilename)
    if let wfJSString = try? String(contentsOf: wfJSFile) {
      jsString = wfJSString
    } else {
      log("Failed to read custom JS file: \(wfJSFile)")
    }
  }

  let webView = InjectedWKWebView(
    frame: .zero,
    configuration: conf,
    cssString: cssString,
    jsString: jsString
  )
  if let userAgent = workflowPaneConfig.paneConfig.customUserAgent {
    webView.customUserAgent = userAgent
  }
  webView.backgroundColor = .clear
  webView.setValue(false, forKey: "drawsBackground")
  webView.wantsLayer = true
  webView.layer?.cornerRadius = cornerRadius
  return webView
}
