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
