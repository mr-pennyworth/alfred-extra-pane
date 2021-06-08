import Alfred
import Cocoa
import Foundation
import WebKit

enum PanePosition {
  enum HorizontalPosition: String, Codable, CodingKey { case left, right }
  enum VerticalPosition: String, Codable, CodingKey { case top, bottom }

  case horizontal(placement: HorizontalPosition, width: Int, minHeight: Int?)
  case vertical(placement: VerticalPosition, height: Int)
}

struct PaneConfig: Codable {
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
    Alfred.onItemSelect { item in
      if (item.workflowuid == self.config.workflowUID)
          || (self.config.workflowUID == "*") {
        if let url = item.quicklookurl {
          return self.render(url)
        }
      }
      self.hide()
    }
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

func makeWindow() -> NSWindow {
  let window = NSWindow(
    contentRect: .zero,
    styleMask: [.borderless, .fullSizeContentView],
    backing: .buffered,
    defer: false,
    screen: NSScreen.main!
  )
  window.level = .floating
  window.collectionBehavior = [
    .canJoinAllSpaces, .stationary, .fullScreenAuxiliary
  ]

  // weird: without the following line
  // the webview just doesn't load!
  window.titlebarAppearsTransparent = true

  // Need this backgrund view gimickry because
  // if we don't have .titled for the window,
  // window.backgroundColor seems to have no effect at all,
  // and we don't want titled because we don't want window border
  let windowBkg = NSView(frame: .zero)
  windowBkg.backgroundColor = NSColor.fromHexString(hex: "#1d1e28", alpha: 1)
  window.contentView = windowBkg

  return window
}

func makeWebView() -> WKWebView {
  let configuration = WKWebViewConfiguration()
  configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
  return WKWebView(frame: .zero, configuration: configuration)
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