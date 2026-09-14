//
//  ZoomImageScrollView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-11.
//

import SwiftUI

/// A scroll view that fits, centres and insets its image from its own bounds.
///
/// Everything here could be worked out from the frame size SwiftUI lays this view out at and applied in `updateUIView(_:context:)`, but that size only describes where the animation ends. SwiftUI animates the frame of a hosted `UIView` by setting it again on every display frame while calling `updateUIView(_:context:)` only once, at the start, so a layout applied there lands while the view is still the size it started at and is only in the right place once the frame catches up. That is the pop seen part way through an ``AutoRotatingView`` rotation.
///
/// Laying out in ``layoutSubviews()`` uses whatever bounds the scroll view has at that moment instead, which is the same thing SwiftUI content does with an animated frame, so the image stays fitted and centred through every frame of the rotation.
final class ZoomImageScrollView: UIScrollView {
    let imageView: UIImageView
    
    /// The safe area insets around this view, as laid out by SwiftUI.
    ///
    /// Taken from SwiftUI rather than read from `safeAreaInsets`, because a UIKit view's own insets come from the window. A viewer rotated to an orientation the app does not support sits in a window that has not rotated with it, so UIKit reports insets belonging to edges the content no longer meets.
    var contentSafeAreaInsets: UIEdgeInsets = .zero {
        didSet { if contentSafeAreaInsets != oldValue { setNeedsLayout() } }
    }
    
    /// The maximum zoom scale asked for, before it is raised to clear the minimum.
    var requestedMaximumZoomScale: CGFloat = 1 {
        didSet { if requestedMaximumZoomScale != oldValue { setNeedsLayout() } }
    }
    
    /// The bounds size the current zoom scales, inset and offset were worked out for.
    private var layoutSize: CGSize = .zero
    
    init(image: UIImage) {
        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        super.init(frame: .zero)
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        clipsToBounds = false
        /// The safe area is applied by ``updateInset()`` from ``contentSafeAreaInsets`` instead, as the insets this scroll view would use are the window's and can belong to the wrong edges when used inside `AutoRotatingView` from FrameUp.
        contentInsetAdjustmentBehavior = .never
        
        addSubview(imageView)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The size of the image before any zoom is applied.
    var imageSize: CGSize {
        imageView.image?.size ?? .zero
    }
    
    /// The zoom scale that fits the image in a frame of `size`.
    func fittingZoomScale(for size: CGSize) -> CGFloat {
        imageSize.zoomScaleToFit(size)
    }
    
    /// The requested maximum zoom scale, raised when needed so it is never below the minimum.
    ///
    /// An image smaller than the frame needs a minimum zoom scale above 1 just to fit, which can be larger than the requested maximum. `UIScrollView` behaves unpredictably when its minimum zoom scale is larger than its maximum, leaving the image too small to fill the frame and refusing to zoom, so the maximum is raised to allow zooming to twice the fitted size. Images at least as large as the frame fit at a scale of 1 or less, so they always use the requested maximum.
    func clampedMaximumZoomScale(for size: CGSize) -> CGFloat {
        max(requestedMaximumZoomScale, fittingZoomScale(for: size) * 2)
    }
    
    override func layoutSubviews() {
        let size = bounds.size
        let previousSize = layoutSize
        layoutSize = size
        
        if size.width > 0, size.height > 0 {
            /// Read before the scales change, as both are measured against the scales in force.
            let wasZoomedOut = previousSize == .zero || isZoomed(to: minimumZoomScale)
            let wasZoomedIn = previousSize != .zero && isZoomed(to: maximumZoomScale)
            /// The part of the image in the middle of the frame, kept there across the resize.
            let centre = previousSize == .zero
                ? CGPoint(cgSize: imageSize / 2)
                : centredImagePoint(in: previousSize)
            
            /// The maximum is set first so the scroll view never briefly has a minimum above its maximum.
            maximumZoomScale = clampedMaximumZoomScale(for: size)
            minimumZoomScale = fittingZoomScale(for: size)
            
            if size != previousSize {
                /// An image resting at either limit stays there, rather than keeping a scale that was only ever the right one for the frame it was worked out in.
                let zoomScale = wasZoomedOut ? minimumZoomScale : wasZoomedIn ? maximumZoomScale : self.zoomScale
                setZoomScaleIfNeeded(zoomScale)
                updateInset()
                setContentOffsetIfNeeded(contentOffset(centring: centre))
            }
        }
        
        super.layoutSubviews()
        
        updateInset()
    }
    
    /// Centres an image smaller than the frame, and insets one larger than it to the safe area so every part of it can be scrolled into view.
    ///
    /// This is what `contentInsetAdjustmentBehavior` does on its own, worked out per axis from the insets SwiftUI laid this view out with rather than the ones the window would supply.
    func updateInset() {
        /// Space left over around the image, negative in an axis where the image overflows.
        let free = bounds.size - contentSize
        /// An image fitted to an axis fills it exactly, and while the frame animates that subtraction lands either side of zero by a fraction of a point. Space too small to draw in counts as none at all, rather than flickering between centring and insetting from one frame of the animation to the next.
        let smallestVisibleLength = 1 / max(traitCollection.displayScale, 1)
        let hasFreeWidth = free.width > smallestVisibleLength
        let hasFreeHeight = free.height > smallestVisibleLength
        
        let contentInset = UIEdgeInsets(
            top: hasFreeHeight ? free.height / 2 : contentSafeAreaInsets.top,
            left: hasFreeWidth ? free.width / 2 : contentSafeAreaInsets.left,
            bottom: hasFreeHeight ? 0 : contentSafeAreaInsets.bottom,
            right: hasFreeWidth ? 0 : contentSafeAreaInsets.right
        )
        
        if self.contentInset != contentInset {
            self.contentInset = contentInset
        }
    }
    
    /// Whether the image is resting at `zoomScale`.
    ///
    /// Compared with a small tolerance, as a scale `UIScrollView` settled on after a pinch is rarely exactly the limit it was clamped to.
    private func isZoomed(to zoomScale: CGFloat) -> Bool {
        abs(self.zoomScale - zoomScale) <= zoomScale * 0.0001
    }
    
    /// The point of the image, before any zoom, that sits in the middle of a frame of `size`.
    private func centredImagePoint(in size: CGSize) -> CGPoint {
        guard zoomScale > 0 else { return CGPoint(cgSize: imageSize / 2) }
        
        return (contentOffset + CGPoint(cgSize: size / 2)) / zoomScale
    }
    
    /// The offset that puts `imagePoint` in the middle of the frame, kept within what can be scrolled to.
    private func contentOffset(centring imagePoint: CGPoint) -> CGPoint {
        let offset = imagePoint * zoomScale - CGPoint(cgSize: bounds.size / 2)
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
    
    /// Zooms without animating, leaving an already matching scale alone so no layout is asked for.
    private func setZoomScaleIfNeeded(_ zoomScale: CGFloat) {
        guard self.zoomScale != zoomScale else { return }
        self.zoomScale = zoomScale
    }
    
    /// Scrolls without animating, leaving an already matching offset alone so no layout is asked for.
    private func setContentOffsetIfNeeded(_ contentOffset: CGPoint) {
        guard self.contentOffset != contentOffset else { return }
        self.contentOffset = contentOffset
    }
}
