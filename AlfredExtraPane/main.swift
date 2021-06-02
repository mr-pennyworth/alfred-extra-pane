import AppKit
import Carbon
import Foundation
import Quartz
import WebKit


typealias Dict = [String: Any]

// Floating webview based on: https://github.com/Qusic/Loaf
class AppDelegate: NSObject, NSApplicationDelegate {
    let minHeight: CGFloat = 500
    let maxWebviewWidth: CGFloat = 300

    let screen: NSScreen = NSScreen.main!
    lazy var screenWidth: CGFloat = screen.frame.width
    lazy var screenHeight: CGFloat = screen.frame.height

    var css = ""

    lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // weird: without the following line
        // the webview just doesn't load!
        window.titlebarAppearsTransparent = true
        
        // Need this backgrund view gimickry because
        // if we don't have .titled for the window, window.backgroundColor seems to
        // have no effect at all, and we don't want titled because we don't want window
        // border
        let windowBkg = NSView(frame: NSRect.init())
        windowBkg.backgroundColor = NSColor.fromHexString(hex: "#1d1e28", alpha: 1)
        window.contentView = windowBkg

        return window
    }()

    lazy var webview: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webview = WKWebView(frame: .zero, configuration: configuration)
        return webview
    }()



    @objc func handleAlfredNotification (notification: NSNotification) {
      log("\(notification)")
      let notif = notification.userInfo! as! Dict
      let notifType = notif["announcement"] as! String
      if (notifType == "window.hidden") {
        self.window.orderOut(self)
      } else if (notifType == "selection.changed") {
        let frame = NSRectFromString(notif["windowframe"] as! String)
        if let selection = notif["selection"] as? Dict {
          if let url = selection["quicklookurl"] as? String {
            if (url.starts(with: "/") && url.hasSuffix(".html")) {
              render(URL(fileURLWithPath: url), NSRectToCGRect(frame))
            } else if (url.hasPrefix("http://") || url.hasPrefix("https://")) {
              render(URL(string: url), NSRectToCGRect(frame))
            } else {
              render(nil, nil)
            }
          } else if let url = selection["subtext"] as? String {
            if (url.starts(with: "/") && url.hasSuffix(".html")) {
              render(URL(fileURLWithPath: url), NSRectToCGRect(frame))
            } else if (url.hasPrefix("http://") || url.hasPrefix("https://")) {
              render(URL(string: url), NSRectToCGRect(frame))
            } else {
              render(nil, nil)
            }
          } else {
            render(nil, nil)
          }
        }
      }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
          self,
          selector: #selector(handleAlfredNotification),
          name: NSNotification.Name(rawValue: "alfred.presssecretary"),
          object: nil,
          suspensionBehavior: .deliverImmediately
        )

      // let ql = QLPreviewView()
      // ql.previewItem = NSURL(fileURLWithPath: "/Users/sujeet/Desktop/core entrance test.pdf")
      // window.contentView?.addSubview(ql)
      window.contentView?.addSubview(webview)
    }

    func showWindow(alfred: CGRect) {
        let height = max(minHeight, alfred.height)
        let webviewWidth = min(screenWidth - alfred.maxX, maxWebviewWidth)
        window.setFrame(
            NSRect(
                x: alfred.minX,
                y: alfred.maxY - height,
                width: alfred.width + webviewWidth,
                height: height),
            display: false
        )
      // let ql = window.contentView?.subviews[0]
      // ql?.setFrameOrigin(NSPoint(x: alfred.width, y: 0))
      // ql?.setFrameSize(NSSize(width: webviewWidth, height: height))
        webview.setFrameOrigin(NSPoint(x: alfred.width, y: 0))
        webview.setFrameSize(NSSize(width: webviewWidth, height: height))
        window.makeKeyAndOrderFront(self)
    }

    func injectCSS(_ html: String) -> String {
        var cssContainer = "body"
        if html.contains("</head>") {
            cssContainer = "head"
        }
        return html.replacingOccurrences(
            of: "</\(cssContainer)>",
            with: "<style>\n\(self.css)</style></\(cssContainer)>"
        )
    }

    func injectCSS(fileUrl: URL) -> URL {
        // if you load html into webview using loadHTMLString,
        // the resultant webview can't be given access to filesystem
        // that means all the css and js references won't resolve anymore
        let injectedHtmlPath = fileUrl.path + ".injected.html"
        let injectedHtmlUrl = URL(fileURLWithPath: injectedHtmlPath)
        let injectedHtml = readFile(named: fileUrl.path, then: injectCSS)!
        try! injectedHtml.write(to: injectedHtmlUrl, atomically: true, encoding: .utf8)
        return injectedHtmlUrl
    }

    func render(_ urlOpt: URL?, _ alfredFrameOpt: CGRect?) {
        if let alfredFrame = alfredFrameOpt {
          if let url = urlOpt {
            if (url.isFileURL) {
              webview.loadFileURL(
                injectCSS(fileUrl: url),
                allowingReadAccessTo: url.deletingLastPathComponent()
              )
            } else {
              webview.load(URLRequest(url: url))
            }
            showWindow(alfred: alfredFrame)
          } else {
            self.window.orderOut(self)
          }
        } else {
          self.window.orderOut(self)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            log("\(url)")
            let param = url.queryParameters
            switch url.host {
            case "update":
                window.contentView?.backgroundColor = NSColor.fromHexString(
                    hex: param["bkgColor"]!,
                    alpha: 1
                )
                readFile(named: param["cssFile"]!, then: { css in self.css = css })
            default:
                break
            }
        }
    }

}


autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
