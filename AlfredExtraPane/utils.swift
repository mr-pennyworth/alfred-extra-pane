import AppKit
import Foundation

func log(
  _ message: String,
  filename: String = #file,
  function: String = #function,
  line: Int = #line
) {
  NSLog("[\(filename.split(separator: "/").last ?? ""):\(function):\(line)] \(message)")
}


extension NSView {
  var backgroundColor: NSColor? {
    get {
      guard let color = layer?.backgroundColor else { return nil }
      return NSColor(cgColor: color)
    }
    set {
      wantsLayer = true
      layer?.backgroundColor = newValue?.cgColor
    }
  }
}


func readFile<T>(named: String, then: (String) -> T) -> T? {
  if let fileContents = try? String(contentsOfFile: named, encoding: .utf8) {
    return then(fileContents)
  } else {
    log("Failed to read file: \(named)")
    return nil
  }
}

// src: https://stackoverflow.com/a/26406426
extension URL {
  var queryParameters: QueryParameters { return QueryParameters(url: self) }
}

class QueryParameters {
  let queryItems: [URLQueryItem]
  init(url: URL?) {
    queryItems = URLComponents(string: url?.absoluteString ?? "")?.queryItems ?? []
    print(queryItems)
  }
  subscript(name: String) -> String? {
    return queryItems.first(where: { $0.name == name })?.value
  }
}
