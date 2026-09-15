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
/// Laying out in ``layoutSubviews()`` uses whatever bounds the scroll view has at that moment instead. While the bounds are animating towards a frame set with ``setTargetFrame(_:)``, the zoomed out scale and the safe area move in a straight line from the layout the animation started at to the one it ends at, which is how the frame of SwiftUI content moves, so the image turns with the rest of the interface rather than growing and shrinking on the way round.
final class ZoomImageScrollView: UIScrollView {
    let imageView: UIImageView
    
    /// The maximum zoom scale asked for, before it is raised to clear the minimum.
    let requestedMaximumZoomScale: CGFloat
    
    /// The frame SwiftUI is laying this view out in, as of its most recent update.
    private(set) var targetFrame: SafeAreaFrame = .zero
    
    /// The layout an animated resize to ``targetFrame`` started from, when the bounds were not already the target's size as it was set.
    private var resizeStart: SafeAreaFrame?
    
    /// The frame the current zoom scales, inset and offset were worked out for, with the safe area as it stood part way through any resize.
    private(set) var layoutFrame: SafeAreaFrame = .zero
    
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
        /// The safe area is applied by ``updateInset()`` from ``targetFrame`` instead, as the insets this scroll view would use are the window's and can belong to the wrong edges when used inside `AutoRotatingView` from FrameUp.
        contentInsetAdjustmentBehavior = .never
        
        if #available(iOS 26, tvOS 26, visionOS 26, *) {
            /// Edge effects blur and fade content that scrolls under a bar at the edge of a scroll view. A fullscreen image has no bars for them to separate it from, and the window decides which edges they appear on, so from iOS 27 a viewer rotated to an orientation the app does not support is blurred along an edge the window's status bar was never near.
            for edgeEffect in [topEdgeEffect, leftEdgeEffect, bottomEdgeEffect, rightEdgeEffect] {
                edgeEffect.isHidden = true
            }
        }
        
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
    
    /// Sets the frame SwiftUI is laying this view out in.
    ///
    /// SwiftUI updates this once, before it starts animating the bounds to the new size. When the bounds are not that size yet, the move from the current layout to the new one is kept so each frame of the animation can be laid out part way between the two.
    func setTargetFrame(_ target: SafeAreaFrame) {
        guard target != targetFrame else { return }
        
        targetFrame = target
        resizeStart = (layoutFrame.size != .zero && layoutFrame.size != target.size && bounds.size != target.size)
            ? layoutFrame
            : nil
        setNeedsLayout()
    }
    
    /// How far bounds of `size` are through the resize from `start` to ``targetFrame``, where 0 is the start and 1 is the end.
    ///
    /// Measured along the axis that changes the most, as SwiftUI moves both axes along the same curve and the larger change is the more precise reading. The result is not clamped, so a spring that overshoots its end carries on past 1 in the same way the frame does.
    func resizeProgress(at size: CGSize, from start: SafeAreaFrame) -> CGFloat {
        let change = targetFrame.size - start.size
        if abs(change.width) >= abs(change.height) {
            return change.width == 0 ? 1 : (size.width - start.size.width) / change.width
        } else {
            return (size.height - start.size.height) / change.height
        }
    }
    
    /// The requested maximum zoom scale, raised when needed so it is never below `minimumZoomScale`.
    ///
    /// An image smaller than the frame needs a minimum zoom scale above 1 just to fit, which can be larger than the requested maximum. `UIScrollView` behaves unpredictably when its minimum zoom scale is larger than its maximum, leaving the image too small to fill the frame and refusing to zoom, so the maximum is raised to allow zooming to twice the fitted size. Images at least as large as the frame fit at a scale of 1 or less, so they always use the requested maximum.
    func clampedMaximumZoomScale(minimumZoomScale: CGFloat) -> CGFloat {
        max(requestedMaximumZoomScale, minimumZoomScale * 2)
    }
    
    /// The safe area insets and minimum zoom scale to lay out bounds of `size` with.
    ///
    /// Outside a resize the image is fitted to the safe area of the target frame. Part way through one, both move in a straight line from where the resize started to where it ends. Fitting the image to each size along the way instead makes it grow and then shrink again, because a frame part way between portrait and landscape is closer to square than either and fits most images at a larger scale than both.
    func layoutValues(at size: CGSize) -> (safeAreaInsets: UIEdgeInsets, minimumZoomScale: CGFloat) {
        guard let resizeStart, size != targetFrame.size else {
            let frame = SafeAreaFrame(size: size, safeAreaInsets: targetFrame.safeAreaInsets)
            return (frame.safeAreaInsets, frame.zoomScaleToFit(imageSize))
        }
        
        let progress = resizeProgress(at: size, from: resizeStart)
        return (
            resizeStart.safeAreaInsets.interpolated(to: targetFrame.safeAreaInsets, progress: progress),
            resizeStart.zoomScaleToFit(imageSize).interpolated(to: targetFrame.zoomScaleToFit(imageSize), progress: progress)
        )
    }
    
    override func layoutSubviews() {
        let size = bounds.size
        
        if size.width > 0, size.height > 0 {
            let (safeAreaInsets, minimumZoomScale) = layoutValues(at: size)
            let frame = SafeAreaFrame(size: size, safeAreaInsets: safeAreaInsets)
            let previousFrame = layoutFrame
            let isFirstLayout = previousFrame.size == .zero
            
            /// Read before the scales change, as both are measured against the scales in force.
            let wasZoomedOut = isFirstLayout || isZoomed(to: self.minimumZoomScale)
            let wasZoomedIn = !isFirstLayout && isZoomed(to: maximumZoomScale)
            /// The part of the image in the middle of the safe area, kept there as the frame changes.
            let centre = isFirstLayout
                ? CGPoint(cgSize: imageSize / 2)
                : centredImagePoint(in: previousFrame)
            
            layoutFrame = frame
            
            /// The maximum is set first so the scroll view never briefly has a minimum above its maximum.
            maximumZoomScale = clampedMaximumZoomScale(minimumZoomScale: minimumZoomScale)
            self.minimumZoomScale = minimumZoomScale
            
            if frame != previousFrame {
                /// An image resting at either limit stays there, rather than keeping a scale that was only ever the right one for the frame it was worked out in.
                let zoomScale = wasZoomedOut ? minimumZoomScale : wasZoomedIn ? maximumZoomScale : self.zoomScale
                setZoomScaleIfNeeded(zoomScale)
                updateInset()
                setContentOffsetIfNeeded(contentOffset(centring: centre, in: frame))
            }
        }
        
        super.layoutSubviews()
        
        updateInset()
    }
    
    /// Centres an image smaller than the safe area inside it, and insets one larger than it to the safe area so every part of it can be scrolled into view.
    ///
    /// This is what `contentInsetAdjustmentBehavior` does on its own, worked out per axis from the insets SwiftUI laid this view out with rather than the ones the window would supply. The insets and a fitted image add up to the bounds, so it cannot be scrolled.
    func updateInset() {
        let contentInset = SafeAreaFrame(size: bounds.size, safeAreaInsets: layoutFrame.safeAreaInsets).insets(around: contentSize)
        
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
    
    /// The point of the image, before any zoom, that sits in the middle of the safe area of `frame`.
    private func centredImagePoint(in frame: SafeAreaFrame) -> CGPoint {
        guard zoomScale > 0 else { return CGPoint(cgSize: imageSize / 2) }
        
        return (contentOffset + frame.safeCentre) / zoomScale
    }
    
    /// The offset that puts `imagePoint` in the middle of the safe area of `frame`, kept within what can be scrolled to.
    private func contentOffset(centring imagePoint: CGPoint, in frame: SafeAreaFrame) -> CGPoint {
        clampedContentOffset(imagePoint * zoomScale - frame.safeCentre)
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
