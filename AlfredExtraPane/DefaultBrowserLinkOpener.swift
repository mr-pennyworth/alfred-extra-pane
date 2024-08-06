import WebKit

/// A WKNavigationDelegate that opens links in the default browser
/// when the command key is pressed.
class DefaultBrowserLinkOpener: NSObject, WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    if navigationAction.navigationType == .linkActivated {
      // Check if the command key is pressed
      if navigationAction.modifierFlags.contains(.command) {
        if let url = navigationAction.request.url {
          // Open the URL in the default browser
          NSWorkspace.shared.open(url)
          // Cancel the navigation in the WKWebView
          decisionHandler(.cancel)
          return
        }
      }
    }
    // Allow the navigation
    decisionHandler(.allow)
  }
}
