import AppKit
import Carbon
import Foundation
import WebKit


// Floating webview based on: https://github.com/Qusic/Loaf
class AppDelegate: NSObject, NSApplicationDelegate {
    var resultHeight: CGFloat = 0
    var resultWidth: CGFloat = 0
    var resultsTopLeftX: CGFloat = 0
    var resultsTopLeftY: CGFloat = 0
    var maxVisibleResults: Int = 9

    var minHeight: CGFloat = 500
    let maxWebviewWidth: CGFloat = 300

    let screen: NSScreen = NSScreen.main!
    lazy var screenWidth: CGFloat = screen.frame.width
    lazy var screenHeight: CGFloat = screen.frame.height

    var urls: [URL?] = []
    var urlIdx = 0
    var css = ""

    let alfredWatcher: AlfredWatcher = AlfredWatcher()

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

    func mouseAt(x: CGFloat, y: CGFloat) {
        let visibleResults = min(maxVisibleResults, urls.count)

        let left = resultsTopLeftX
        let right = left + resultWidth
        let top = resultsTopLeftY
        let bottom = top + resultHeight * CGFloat(visibleResults)

        if ((left < x) && (x < right) && (top < y) && (y < bottom)) {
            let i = Int((y - top) / resultHeight)
            if (i != urlIdx) {
                urlIdx = i
                render()
            }
        }
    }

    func setUrls(_ urlListJsonString: String) {
        self.urlIdx = 0
        let data = Data(urlListJsonString.utf8)
        do {
            let array = try JSONSerialization.jsonObject(with: data) as! [String]
            
            // empty strings map to file URL equivalent to "./",
            // which we later on decide to not render in render()
            self.urls = array.map({path in
                if (path.starts(with: "/")) {
                    return URL(fileURLWithPath: path)
                } else {
                    return URL(string: path)
                }
            })
            render()
            // puzzler: why would the following cause a SEGFAULT?
            //          that too never while running in xcode
            // log("urls: \(self.urls)")
        } catch {
            log("Error: \(error)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The following mouse events take some time to start firing: why??
        NSEvent.addGlobalMonitorForEvents(
          matching: [NSEvent.EventTypeMask.mouseMoved],
          handler: { (event: NSEvent) in
              let loc = event.locationInWindow
              self.mouseAt(x: loc.x, y: self.screenHeight - loc.y)
          }
        )

        window.contentView?.addSubview(webview)
        alfredWatcher.start(
            onAlfredWindowDestroy: {
                self.urls = [nil]
                self.window.orderOut(self)
            },
            onDownArrowPressed: self.renderNext,
            onUpArrowPressed: self.renderPrevious
        )
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

    func render() {
        if (self.urls.count == 0 || self.urls == [nil]) {
            return
        }

        if let alfredFrame = self.alfredWatcher.alfredFrame() {
            self.urlIdx = (self.urlIdx + self.urls.count) % self.urls.count
            if let url = self.urls[self.urlIdx] {
                log("Rendering URL at index: \(self.urlIdx): \(url)")
                if (url.isFileURL) {
                    webview.loadFileURL(
                        injectCSS(fileUrl: url),
                        allowingReadAccessTo: url.deletingLastPathComponent()
                    )
                } else {
                    webview.load(URLRequest(url: url))
                }
                webview.isHidden = false
                showWindow(alfred: alfredFrame)
            } else {
                log("Hiding as no URL was provided at index: \(self.urlIdx)")
                webview.isHidden = true
            }
        }
    }

    func renderNext() {
        self.urlIdx += 1
        self.render()
    }
    
    func renderPrevious() {
        self.urlIdx -= 1
        self.render()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            log("\(url)")
            let param = url.queryParameters
            switch url.host {
            case "update":
                minHeight = CGFloat(Int(param["minHeight"]!)!)
                maxVisibleResults = Int(param["maxVisibleResults"]!)!
                resultHeight = CGFloat(Int(param["resultHeight"]!)!)
                resultWidth = CGFloat(Int(param["resultWidth"]!)!)

                if let alfredFrame = self.alfredWatcher.alfredFrame() {
                    resultsTopLeftX =
                      CGFloat(Int(param["resultsTopLeftX"]!)!) + alfredFrame.minX
                    resultsTopLeftY =
                      CGFloat(Int(param["resultsTopLeftY"]!)!) + screenHeight - alfredFrame.maxY
                }

                window.contentView?.backgroundColor = NSColor.fromHexString(
                    hex: param["bkgColor"]!,
                    alpha: 1
                )
                readFile(named: param["cssFile"]!, then: { css in self.css = css })
                readFile(named: param["specFile"]!, then: setUrls)
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
