//
//  EdgeInsets-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-11.
//

import SwiftUI

extension EdgeInsets {
    /// These insets as `UIEdgeInsets`, resolving leading and trailing into left and right.
    /// - Parameter layoutDirection: Layout direction used to decide which side leading is on.
    /// - Returns: The same insets in the form UIKit uses.
    func uiEdgeInsets(layoutDirection: LayoutDirection) -> UIEdgeInsets {
        let isLeftToRight = layoutDirection == .leftToRight
        return UIEdgeInsets(
            top: top,
            left: isLeftToRight ? leading : trailing,
            bottom: bottom,
            right: isLeftToRight ? trailing : leading
        )
    }
}

extension UIEdgeInsets {
    /// These insets moved `progress` of the way towards `end`, edge by edge.
    func interpolated(to end: UIEdgeInsets, progress: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(
            top: top.interpolated(to: end.top, progress: progress),
            left: left.interpolated(to: end.left, progress: progress),
            bottom: bottom.interpolated(to: end.bottom, progress: progress),
            right: right.interpolated(to: end.right, progress: progress)
        )
    }
}
