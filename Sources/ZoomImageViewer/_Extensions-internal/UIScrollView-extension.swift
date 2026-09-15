//
//  UIScrollView-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import UIKit

extension UIScrollView {
    /// `offset` kept within what can be scrolled to, including the content inset.
    func clampedContentOffset(_ offset: CGPoint) -> CGPoint {
        let minimum = CGPoint(x: -contentInset.left, y: -contentInset.top)
        let maximum = CGPoint(
            x: max(minimum.x, contentSize.width + contentInset.right - bounds.width),
            y: max(minimum.y, contentSize.height + contentInset.bottom - bounds.height)
        )
        
        return CGPoint(
            x: min(max(offset.x, minimum.x), maximum.x),
            y: min(max(offset.y, minimum.y), maximum.y)
        )
    }
    
    /// The offset `distance` towards `edge` of the content from the current one, stopping where the content ends.
    /// - Parameters:
    ///   - edge: The edge to scroll towards. Only the width of `distance` is used for left and right, and only its height for top and bottom.
    ///   - distance: How far to scroll.
    func contentOffset(scrollingTowards edge: UIRectEdge, by distance: CGSize) -> CGPoint {
        var offset = contentOffset
        
        switch edge {
        case .top:
            offset.y -= distance.height
        case .bottom:
            offset.y += distance.height
        case .left:
            offset.x -= distance.width
        case .right:
            offset.x += distance.width
        default:
            break
        }
        
        return clampedContentOffset(offset)
    }
}
