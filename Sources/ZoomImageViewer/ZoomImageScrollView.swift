//
//  ZoomImageScrollView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-11.
//

import SwiftUI

/// A scroll view that fits, centres and insets its image from its own bounds.
///
/// Like in Photos, the image ignores the safe area. It is fitted and centred in the whole frame, and a zoomed in image can be scrolled right to the edges of the screen, under the status bar and home indicator. The overlay is laid out by SwiftUI inside the safe area, so controls over the image stay clear of them.
///
/// Everything here could be worked out from the frame size SwiftUI lays this view out at and applied in `updateUIView(_:context:)`, but that size only describes where the animation ends. SwiftUI animates the frame of a hosted `UIView` by setting it again on every display frame while calling `updateUIView(_:context:)` only once, at the start, so a layout applied there lands while the view is still the size it started at and is only in the right place once the frame catches up. That is the pop seen part way through an ``AutoRotatingView`` rotation.
///
/// Laying out in ``layoutSubviews()`` uses whatever bounds the scroll view has at that moment instead. While the bounds are animating towards a size set with ``setTargetSize(_:)``, the zoomed out scale moves in a straight line from the layout the animation started at to the one it ends at, which is how the frame of SwiftUI content moves, so the image turns with the rest of the interface rather than growing and shrinking on the way round.
final class ZoomImageScrollView: UIScrollView {
    let imageView: UIImageView
    
    /// The maximum zoom scale asked for, before it is raised to clear the minimum.
    let requestedMaximumZoomScale: CGFloat
    
    /// The size SwiftUI is laying this view out at, as of its most recent update.
    private(set) var targetSize: CGSize = .zero
    
    /// The size an animated resize to ``targetSize`` started from, when the bounds were not already the target size as it was set.
    private var resizeStart: CGSize?
    
    /// The size the current zoom scales, inset and offset were worked out for.
    private(set) var layoutSize: CGSize = .zero
    
    init(image: UIImage, maximumZoomScale: CGFloat) {
        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        /// Needed for the double tap to zoom. Turning off interaction on the scroll view already cuts off its subviews, so this never has to be turned off again.
        imageView.isUserInteractionEnabled = true
        requestedMaximumZoomScale = maximumZoomScale
        
        super.init(frame: .zero)
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        clipsToBounds = false
        /// The image ignores the safe area, and the insets this scroll view would add are the window's, which can belong to the wrong edges when used inside `AutoRotatingView` from FrameUp. ``updateInset()`` only centres the image.
        contentInsetAdjustmentBehavior = .never
        
        if #available(iOS 26, tvOS 26, visionOS 26, *) {
            /// Edge effects blur and fade content that scrolls under a bar at the edge of a scroll view. A fullscreen image has no bars for them to separate it from, and the window decides which edges they appear on, so from iOS 27 a viewer rotated to an orientation the app does not support is blurred along an edge the window's status bar was never near.
            for edgeEffect in [topEdgeEffect, leftEdgeEffect, bottomEdgeEffect, rightEdgeEffect] {
                edgeEffect.isHidden = true
            }
        }
        
        addSubview(imageView)
        /// `UIScrollView` only updates its content size when it zooms. An image that fits at a scale of 1, which a new scroll view already has, is never zoomed to fit, so without this its content size stays empty and centring it puts the image's top left corner in the middle of the screen.
        contentSize = imageView.frame.size
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The size of the image before any zoom is applied.
    var imageSize: CGSize {
        imageView.image?.size ?? .zero
    }
    
    /// Sets the size SwiftUI is laying this view out at.
    ///
    /// SwiftUI updates this once, before it starts animating the bounds to the new size. When the bounds are not that size yet, the size they are moving from is kept so each frame of the animation can be laid out part way between the two.
    func setTargetSize(_ target: CGSize) {
        guard target != targetSize else { return }
        
        targetSize = target
        resizeStart = (layoutSize != .zero && layoutSize != target && bounds.size != target)
            ? layoutSize
            : nil
        setNeedsLayout()
    }
    
    /// How far bounds of `size` are through the resize from `start` to ``targetSize``, where 0 is the start and 1 is the end.
    ///
    /// Measured along the axis that changes the most, as SwiftUI moves both axes along the same curve and the larger change is the more precise reading. The result is not clamped, so a spring that overshoots its end carries on past 1 in the same way the frame does.
    func resizeProgress(at size: CGSize, from start: CGSize) -> CGFloat {
        let change = targetSize - start
        if abs(change.width) >= abs(change.height) {
            return change.width == 0 ? 1 : (size.width - start.width) / change.width
        } else {
            return (size.height - start.height) / change.height
        }
    }
    
    /// The requested maximum zoom scale, raised when needed so it is never below `minimumZoomScale`.
    ///
    /// An image smaller than the frame needs a minimum zoom scale above 1 just to fit, which can be larger than the requested maximum. `UIScrollView` behaves unpredictably when its minimum zoom scale is larger than its maximum, leaving the image too small to fill the frame and refusing to zoom, so the maximum is raised to allow zooming to twice the fitted size. Images at least as large as the frame fit at a scale of 1 or less, so they always use the requested maximum.
    func clampedMaximumZoomScale(minimumZoomScale: CGFloat) -> CGFloat {
        max(requestedMaximumZoomScale, minimumZoomScale * 2)
    }
    
    /// The zoom scale that fits the image in bounds of `size`, used as the minimum zoom scale.
    ///
    /// Outside a resize the image is fitted to `size` itself. Part way through one, the scale moves in a straight line from where the resize started to where it ends. Fitting the image to each size along the way instead makes it grow and then shrink again, because a frame part way between portrait and landscape is closer to square than either and fits most images at a larger scale than both.
    func fittedZoomScale(at size: CGSize) -> CGFloat {
        guard let resizeStart, size != targetSize else {
            return imageSize.zoomScaleToFit(size)
        }
        
        let progress = resizeProgress(at: size, from: resizeStart)
        return imageSize.zoomScaleToFit(resizeStart).interpolated(to: imageSize.zoomScaleToFit(targetSize), progress: progress)
    }
    
    override func layoutSubviews() {
        let size = bounds.size
        
        if size.width > 0, size.height > 0 {
            let minimumZoomScale = fittedZoomScale(at: size)
            let previousSize = layoutSize
            let isFirstLayout = previousSize == .zero
            
            /// Read before the scales change, as both are measured against the scales in force.
            let wasZoomedOut = isFirstLayout || isZoomed(to: self.minimumZoomScale)
            let wasZoomedIn = !isFirstLayout && isZoomed(to: maximumZoomScale)
            /// The part of the image in the middle of the view, kept there as the size changes.
            let centre = isFirstLayout
                ? CGPoint(cgSize: imageSize / 2)
                : centredImagePoint(in: previousSize)
            
            layoutSize = size
            
            /// The maximum is set first so the scroll view never briefly has a minimum above its maximum.
            maximumZoomScale = clampedMaximumZoomScale(minimumZoomScale: minimumZoomScale)
            self.minimumZoomScale = minimumZoomScale
            
            if size != previousSize {
                /// An image resting at either limit stays there, rather than keeping a scale that was only ever the right one for the size it was worked out at.
                let zoomScale = wasZoomedOut ? minimumZoomScale : wasZoomedIn ? maximumZoomScale : self.zoomScale
                setZoomScaleIfNeeded(zoomScale)
                updateInset()
                setContentOffsetIfNeeded(contentOffset(centring: centre, in: size))
            }
        }
        
        super.layoutSubviews()
        
        updateInset()
    }
    
    /// Centres an image smaller than the bounds inside them. An axis the image overflows has no inset, so every part of the image can be scrolled to the edge of the screen.
    ///
    /// Worked out per axis from the bounds as they are right now. The insets and a fitted image add up to the bounds, so it cannot be scrolled. As the image grows past the bounds the inset shrinks to nothing without a jump, so an image fitted exactly to one axis does not flicker while the frame animates.
    func updateInset() {
        let free = CGSize(
            width: max(0, bounds.width - contentSize.width),
            height: max(0, bounds.height - contentSize.height)
        )
        let contentInset = UIEdgeInsets(top: free.height / 2, left: free.width / 2, bottom: free.height / 2, right: free.width / 2)
        
        if self.contentInset != contentInset {
            self.contentInset = contentInset
        }
    }
    
    /// Whether the image is zoomed in past the scale that fits it.
    ///
    /// A scale within the tolerance of ``isZoomed(to:)`` still counts as fitted, so a pinch that settles back at the minimum is not zoomed in. A scale bouncing below the minimum is not zoomed in either.
    var isZoomedIn: Bool {
        zoomScale > minimumZoomScale && !isZoomed(to: minimumZoomScale)
    }
    
    /// Whether the image is resting at `zoomScale`.
    ///
    /// Compared with a small tolerance, as a scale `UIScrollView` settled on after a pinch is rarely exactly the limit it was clamped to.
    private func isZoomed(to zoomScale: CGFloat) -> Bool {
        abs(self.zoomScale - zoomScale) <= zoomScale * 0.0001
    }
    
    /// The point of the image, before any zoom, that sits in the middle of bounds of `size`.
    private func centredImagePoint(in size: CGSize) -> CGPoint {
        guard zoomScale > 0 else { return CGPoint(cgSize: imageSize / 2) }
        
        return (contentOffset + CGPoint(cgSize: size / 2)) / zoomScale
    }
    
    /// The offset that puts `imagePoint` in the middle of bounds of `size`, kept within what can be scrolled to.
    private func contentOffset(centring imagePoint: CGPoint, in size: CGSize) -> CGPoint {
        clampedContentOffset(imagePoint * zoomScale - CGPoint(cgSize: size / 2))
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
