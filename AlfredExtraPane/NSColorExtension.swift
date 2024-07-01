// source: https://gist.github.com/rpomeroy/c0bf58a2c62f34fdad8d

import Cocoa
import Foundation


extension String  {
  func conformsTo(pattern: String) -> Bool {
    let pattern = NSPredicate(format:"SELF MATCHES %@", pattern)
    return pattern.evaluate(with: self)
  }
}

extension NSColor {
  class func from(hex: String) -> NSColor? {
    // Handle two types of literals: 0x and # prefixed
    let cleanedStr = hex
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "0x", with: "")
      .replacingOccurrences(of: "#", with: "")
    
    // Accept only rrggbbaa or rrggbb
    let hexChars = "[a-fA-F0-9]"
    let validColor = "^(\(hexChars){6}|\(hexChars){8})$"
    if !cleanedStr.conformsTo(pattern: validColor) {
      return nil
    }

    // convert rrggbb to rrggbb00
    let colorStr = if cleanedStr.count == 6 {
      cleanedStr + "00"
    } else {
      cleanedStr
    }
    
    var rgba: UInt64 = 0
    Scanner(string: colorStr).scanHexInt64(&rgba)
    let r = CGFloat((rgba & 0xFF000000) >> 24) / 255.0
    let g = CGFloat((rgba & 0x00FF0000) >> 16) / 255.0
    let b = CGFloat((rgba & 0x0000FF00) >> 8) / 255.0
    let a = CGFloat(rgba & 0x000000FF) / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: a)
  }
}
