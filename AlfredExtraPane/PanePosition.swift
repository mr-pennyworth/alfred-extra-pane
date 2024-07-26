import Cocoa
import Foundation

enum PanePosition: Equatable {
  enum HorizontalPlacement: String, Codable, CodingKey { case left, right }
  enum VerticalPlacement: String, Codable, CodingKey { case top, bottom }

  case horizontal(placement: HorizontalPlacement, width: Int, minHeight: Int?)
  case vertical(placement: VerticalPlacement, height: Int, width: Int?)
}

extension NSRect {
  init(at position: PanePosition, wrt ref: NSRect, withMargin margin: CGFloat) {
    let screen = ref.screenFrame

    let width: CGFloat = {
      switch position {
      case .horizontal(.left, let w, _): min(
        CGFloat(w),
        ref.horizontalSpaceLeft - 2 * margin
      )
      case .horizontal(.right, let w, _): min(
        CGFloat(w),
        ref.horizontalSpaceRight - 2 * margin
      )
      case .vertical(_, _, nil): min(
        ref.width,
        screen.width - 2 * margin
      )
      case .vertical(_, _, let w?): min(
        CGFloat(w),
        screen.width - 2 * margin
      )
      }
    }()

    let height: CGFloat = {
      switch position {
      case .horizontal(_, _, nil): ref.height
      case .horizontal(_, _, let mh?): max(CGFloat(mh), ref.height)
      case .vertical(.bottom, let h, _): min(
        CGFloat(h),
        ref.verticalSpaceBelow - 2 * margin
      )
      case .vertical(.top, let h, _): min(
        CGFloat(h),
        ref.verticalSpaceAbove - 2 * margin
      )
      }
    }()

    let x: CGFloat = {
      switch position {
      case .vertical(_, _, _): ref.minX + (ref.width - width) / 2
      case .horizontal(.left, _, _): ref.minX - (width + margin)
      case .horizontal(.right, _, _): ref.minX + (ref.width + margin)
      }
    }()

    let y: CGFloat = {
      switch position {
      case .horizontal(_, _, _): ref.maxY - height
      case .vertical(.top, _, _): ref.maxY + margin
      case .vertical(.bottom, _, _): ref.minY - (height + margin)
      }
    }()

    self.init(x: x, y: y, width: width, height: height)
  }

  var screenFrame: NSRect {
    NSScreen.screens.first(where: { $0.frame.intersects(self) })!.visibleFrame
  }

  var verticalSpaceBelow: CGFloat { minY - screenFrame.minY }

  var verticalSpaceAbove: CGFloat { screenFrame.maxY - maxY }

  var horizontalSpaceRight: CGFloat { screenFrame.maxX - maxX }

  var horizontalSpaceLeft: CGFloat { minX - screenFrame.minX }
}

