import Alfred
import WebKit

/// Once the CSS in injected, the JS that did the injection will send
/// a message with this name to the webview. See `injecterJS`.
private let cssInjectedMessageName = "cssInjected"

/// There's no way to directly inject CSS into a WKWebView.
/// The only way is to inject a <style> tag into the document by executing
/// JS in the webview.
private func injecterJS(_ cssString: String) -> String {
  let escapedCssString = cssString.replacingOccurrences(of: "\\", with: "\\\\")
  return """
  var style = document.createElement('style');
  style.innerHTML = `\(escapedCssString)`;
  document.head.appendChild(style);
  window.webkit.messageHandlers.\(cssInjectedMessageName).postMessage('done');
  """
}

class InjectedWKWebView: WKWebView, WKScriptMessageHandler {
  // This is required because we're subclassing WKWebView,
  // and has nothing to do with the CSS injection.
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  init(
    frame: CGRect,
    configuration: WKWebViewConfiguration,
    cssString: String,
    jsString: String
  ) {
    log("will inject CSS: \(cssString)")
    log("will inject JS: \(jsString)")

    let userScript = WKUserScript(
      source: "\(jsString)\n\(injecterJS(cssString))",
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )

    let contentController = WKUserContentController()
    contentController.addUserScript(userScript)

    configuration.userContentController = contentController
    super.init(frame: frame, configuration: configuration)

    contentController.add(self, name: cssInjectedMessageName)
  }

  override func load(_ request: URLRequest) -> WKNavigation? {
    // we don't want the webview to be visible till the css is injected, and
    // has taken effect.
    self.isHidden = true
    return super.load(request)
  }

  override func loadFileURL(
    _ URL: URL,
    allowingReadAccessTo readAccessURL: URL
  ) -> WKNavigation? {
    // we don't want the webview to be visible till the css is injected, and
    // has taken effect.
    self.isHidden = true
    return super.loadFileURL(URL, allowingReadAccessTo: readAccessURL)
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    // Once the CSS is injected, make the webview visible.
    if message.name == cssInjectedMessageName {
      self.isHidden = false
    }
  }
}
