//
//  UIRectEdge-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI

extension UIRectEdge {
    /// The edge of the content to scroll towards for an edge passed to `accessibilityScrollAction(_:)`, resolving leading and trailing into left and right.
    ///
    /// Horizontal edges come through the other way round from the edge of the content to bring into view, so leading resolves to the trailing side.
    /// - Parameter layoutDirection: Layout direction used to decide which side leading is on.
    init(accessibilityScrollEdge edge: Edge, layoutDirection: LayoutDirection) {
        let isLeftToRight = layoutDirection == .leftToRight
        switch edge {
        case .top:
            self = .top
        case .bottom:
            self = .bottom
        case .leading:
            self = isLeftToRight ? .right : .left
        case .trailing:
            self = isLeftToRight ? .left : .right
        }
    }
}
