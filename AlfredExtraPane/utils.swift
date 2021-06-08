import Alfred
import AppKit
import Foundation


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

public func read<T: Codable>(contentsOf filepath: URL) -> T? {
  do {
    let data = try Data(contentsOf: filepath)
    return try JSONDecoder().decode(T.self, from: data)
  } catch {
    log("\(error)")
    log("Error: Couldn't read JSON object from: \(filepath.path)")
  }
  return nil
}

public func write<T: Codable>(_ obj: T, to filepath: URL) {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted
  do {
    let data = try encoder.encode(obj)
    try data.write(to: filepath)
  } catch {
    log("\(error)")
    log("Error: Couldn't write JSON object to: \(filepath.path)")
    log("Error: Couldn't write object: \(obj)")
  }
}
