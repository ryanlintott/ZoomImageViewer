//
//  SafeAreaFrame.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// A frame size, including its safe area, together with the safe area insets inside it.
///
/// Both the scroll view showing an image and the shape that blocks gestures around it fit and centre the image inside this safe area, so they share it rather than each working it out.
struct SafeAreaFrame: Equatable {
    var size: CGSize
    var safeAreaInsets: UIEdgeInsets
    
    static let zero = SafeAreaFrame(size: .zero, safeAreaInsets: .zero)
    
    /// The frame a geometry proxy describes, with leading and trailing insets resolved into left and right so they can be handed to UIKit.
    init(_ proxy: GeometryProxy, layoutDirection: LayoutDirection) {
        self.init(size: proxy.sizeIncludingSafeAreaInsets, safeAreaInsets: proxy.safeAreaInsets.uiEdgeInsets(layoutDirection: layoutDirection))
    }
    
    init(size: CGSize, safeAreaInsets: UIEdgeInsets) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }
    
    /// The size of the part of the frame inside the safe area.
    var safeSize: CGSize {
        CGSize(
            width: size.width - safeAreaInsets.left - safeAreaInsets.right,
            height: size.height - safeAreaInsets.top - safeAreaInsets.bottom
        )
    }
    
    /// The middle of the part of the frame inside the safe area, relative to the frame's origin.
    var safeCentre: CGPoint {
        CGPoint(x: safeAreaInsets.left + safeSize.width / 2, y: safeAreaInsets.top + safeSize.height / 2)
    }
    
    /// The zoom scale that fits content of `contentSize` inside the safe area.
    func zoomScaleToFit(_ contentSize: CGSize) -> CGFloat {
        contentSize.zoomScaleToFit(safeSize)
    }
    
    /// The space on each edge of the frame around content of `contentSize` centred inside the safe area.
    ///
    /// Space left over inside the safe area is split evenly either side of the content, so the insets and the content add up to the whole frame. In an axis the content overflows, the insets are the safe area itself. As the space runs out both settle on the safe area without a jump, so content fitted exactly to one axis does not flicker between the two while the frame animates.
    func insets(around contentSize: CGSize) -> UIEdgeInsets {
        let free = CGSize(
            width: max(0, safeSize.width - contentSize.width),
            height: max(0, safeSize.height - contentSize.height)
        )
        
        return UIEdgeInsets(
            top: safeAreaInsets.top + free.height / 2,
            left: safeAreaInsets.left + free.width / 2,
            bottom: safeAreaInsets.bottom + free.height / 2,
            right: safeAreaInsets.right + free.width / 2
        )
    }
}
