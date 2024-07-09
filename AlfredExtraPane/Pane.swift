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

public struct PaneConfig: Codable, Equatable {
  let alignment: PanePosition
  let workflowUID: String
}

class Pane {
  let config: PaneConfig
  var alfredFrame: NSRect = .zero
  let window: NSWindow = makeWindow()
  let webView: WKWebView = makeWebView()
  let margin: CGFloat = 5

  init(config: PaneConfig) {
    self.config = config
    window.contentView!.addSubview(webView)

    Alfred.onHide { self.hide() }
    Alfred.onFrameChange { self.alfredFrame = $0 }
  }

  lazy var isWildcard: Bool = { self.config.workflowUID == "*" }()

  func matchesExactly(item: Alfred.SelectedItem) -> Bool {
    item.workflowuid == self.config.workflowUID
  }

  func render(_ url: URL) {
    if url.isFileURL {
      if url.absoluteString.hasSuffix(".html") {
        let dir = url.deletingLastPathComponent()
        webView.loadFileURL(injectCSS(url), allowingReadAccessTo: dir)
      } else {
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
    window.makeKeyAndOrderFront(self)
  }

  func hide() {
    window.orderOut(self)
  }
}

let cornerRadius =
  CGFloat((Alfred.theme["window-roundness"] as? Float) ?? 0)

func makeWindow() -> NSWindow {
  let windowColorHex =
    (Alfred.theme["window-color"] as? String) ?? "#1d1e28ff"
  let windowColor = NSColor.from(hex: windowColorHex)!

  let window = NSWindow(
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

func makeWebView() -> WKWebView {
  let conf = WKWebViewConfiguration()
  conf.preferences.setValue(true, forKey: "developerExtrasEnabled")

  // TODO: allow configuration from prefs.json
  // we don't want the pane to autoplay audio from the loaded webpage.
  // (ideally, we want to be able to configure it, but till then, the
  // quick fix is to disable autoplay).
  conf.mediaTypesRequiringUserActionForPlayback = .all

  let webView = WKWebView(frame: .zero, configuration: conf)
  webView.backgroundColor = .clear
  webView.setValue(false, forKey: "drawsBackground")
  webView.wantsLayer = true
  webView.layer?.cornerRadius = cornerRadius
  return webView
}

func injectCSS(_ html: String) -> String {
  var cssContainer = "body"
  if html.contains("</head>") {
    cssContainer = "head"
  }
  return html.replacingOccurrences(
    of: "</\(cssContainer)>",
    with: "<style>\n\(Alfred.themeCSS)</style></\(cssContainer)>"
  )
}

func injectCSS(_ fileUrl: URL) -> URL {
  // if you load html into webview using loadHTMLString,
  // the resultant webview can't be given access to filesystem
  // that means all the css and js references won't resolve anymore
  let injectedHtmlPath = fileUrl.path + ".injected.html"
  let injectedHtmlUrl = URL(fileURLWithPath: injectedHtmlPath)
  let injectedHtml = readFile(named: fileUrl.path, then: injectCSS)!
  try! injectedHtml.write(to: injectedHtmlUrl, atomically: true, encoding: .utf8)
  return injectedHtmlUrl
}
