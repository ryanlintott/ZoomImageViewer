//
//  ZoomScaleTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-03.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points.
private let frame = CGSize(width: 393, height: 852)

/// The maximum zoom scale `_ZoomImageView` requests.
private let requestedMaximumZoomScale: CGFloat = 2

/// Image sizes at least as large as the frame, which fit at a zoom scale of 1 or less.
private let largeSizes: [CGSize] = [
    .init(width: 4000, height: 3000),
    .init(width: 1179, height: 2556),
    .init(width: 393, height: 852),
    .init(width: 300, height: 1200),
    .init(width: 852, height: 393)
]

/// Image sizes smaller than the frame, which need a zoom scale above 1 to fit.
private let smallSizes: [CGSize] = [
    .init(width: 60, height: 60),
    .init(width: 200, height: 400),
    .init(width: 392, height: 851),
    .init(width: 1, height: 1)
]

@Suite("CGSize.zoomScaleToFit")
struct ZoomScaleToFitTests {
    @Test("An image wider than the frame is limited by the frame width")
    func widerImageIsLimitedByFrameWidth() {
        let expected: CGFloat = 393 / 4000
        #expect(CGSize(width: 4000, height: 3000).zoomScaleToFit(frame) == expected)
    }

    @Test("An image taller than the frame is limited by the frame height")
    func tallerImageIsLimitedByFrameHeight() {
        let expected: CGFloat = 852 / 1200
        #expect(CGSize(width: 300, height: 1200).zoomScaleToFit(frame) == expected)
    }

    @Test("An image matching the frame needs no zoom")
    func matchingImageNeedsNoZoom() {
        #expect(CGSize(width: 393, height: 852).zoomScaleToFit(frame) == 1)
    }

    /// A zero dimension used to give an infinite or undefined scale, which reached `setZoomScale`.
    @Test("A size with no width or height needs no zoom", arguments: [
        CGSize.zero,
        .init(width: 0, height: 100),
        .init(width: 100, height: 0)
    ])
    func emptySizeNeedsNoZoom(imageSize: CGSize) {
        #expect(imageSize.zoomScaleToFit(frame) == 1)
    }

    @Test("A frame with no width or height needs no zoom", arguments: [
        CGSize.zero,
        .init(width: 0, height: 852),
        .init(width: 393, height: 0)
    ])
    func emptyFrameNeedsNoZoom(frameSize: CGSize) {
        #expect(CGSize(width: 4000, height: 3000).zoomScaleToFit(frameSize) == 1)
    }

    @Test("An image smaller than the frame is zoomed up to fit")
    func smallImageIsZoomedUpToFit() {
        let expected: CGFloat = 393 / 60
        #expect(CGSize(width: 60, height: 60).zoomScaleToFit(frame) == expected)
    }

    /// The scale must reproduce the size that `scaledToFit(_:)` lays the image out at.
    @Test("The scale matches the scaled size", arguments: largeSizes + smallSizes)
    func scaleMatchesScaledSize(imageSize: CGSize) {
        let scale = imageSize.zoomScaleToFit(frame)
        let scaled = imageSize.scaledToFit(frame)

        #expect(abs(imageSize.width * scale - scaled.width) < 0.0001)
        #expect(abs(imageSize.height * scale - scaled.height) < 0.0001)
    }

    @Test("Images at least as large as the frame fit at a scale of 1 or less", arguments: largeSizes)
    func largeImagesFitAtOrBelowOne(imageSize: CGSize) {
        #expect(imageSize.zoomScaleToFit(frame) <= 1)
    }

    @Test("Images smaller than the frame need a scale above 1", arguments: smallSizes)
    func smallImagesNeedScaleAboveOne(imageSize: CGSize) {
        #expect(imageSize.zoomScaleToFit(frame) > 1)
    }
}

/// The maximum zoom scale is a policy of the view rather than pure geometry, so it is checked through the scroll view that applies it.
@MainActor
@Suite("ZoomImageScrollView zoom scales")
struct ScrollViewZoomScaleTests {
    /// The whole frame with no safe area, so fitting to the safe area is fitting to the frame.
    static let unsafeFrame = SafeAreaFrame(size: frame, safeAreaInsets: .zero)

    /// An image of an exact size, drawn at a scale of 1 to keep the backing bitmap small.
    static func image(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in }
    }

    static func scrollView(
        imageSize: CGSize,
        maximumZoomScale: CGFloat = requestedMaximumZoomScale
    ) -> ZoomImageScrollView {
        ZoomImageScrollView(image: image(size: imageSize), maximumZoomScale: maximumZoomScale)
    }

    static func maximum(for scrollView: ZoomImageScrollView) -> CGFloat {
        scrollView.clampedMaximumZoomScale(minimumZoomScale: unsafeFrame.zoomScaleToFit(scrollView.imageSize))
    }

    @Test("The minimum zoom scale is the scale needed to fit", arguments: largeSizes + smallSizes)
    func minimumIsScaleToFit(imageSize: CGSize) {
        #expect(Self.unsafeFrame.zoomScaleToFit(imageSize) == imageSize.zoomScaleToFit(frame))
    }

    /// A tall and skinny image used to be fitted to the whole frame, leaving its ends under the status bar and home indicator when it first opened.
    @Test("The minimum zoom scale fits the image inside the safe area")
    func minimumFitsInsideSafeArea() {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let safeFrame = SafeAreaFrame(size: frame, safeAreaInsets: insets)
        let imageSize = CGSize(width: 141, height: 1573)

        #expect(safeFrame.zoomScaleToFit(imageSize) == (frame.height - 59 - 34) / imageSize.height)
    }

    /// A minimum zoom scale above the maximum leaves `UIScrollView` unable to zoom, and showing the image too small to fill the frame. `UIImage()` has no size, which used to give an infinite minimum zoom scale.
    @Test("An image with no size gets usable zoom scales")
    func emptyImageGetsUsableZoomScales() {
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: requestedMaximumZoomScale)

        #expect(Self.unsafeFrame.zoomScaleToFit(scrollView.imageSize) == 1)
        #expect(Self.maximum(for: scrollView) == requestedMaximumZoomScale)
    }

    @Test("The maximum is never below the minimum", arguments: largeSizes + smallSizes)
    func maximumIsNeverBelowMinimum(imageSize: CGSize) {
        let scrollView = Self.scrollView(imageSize: imageSize)

        #expect(Self.maximum(for: scrollView) >= Self.unsafeFrame.zoomScaleToFit(scrollView.imageSize))
    }

    @Test("Images at least as large as the frame use the requested maximum", arguments: largeSizes)
    func largeImagesUseRequestedMaximum(imageSize: CGSize) {
        #expect(Self.maximum(for: Self.scrollView(imageSize: imageSize)) == requestedMaximumZoomScale)
    }

    @Test("Images smaller than the frame can still zoom in", arguments: smallSizes)
    func smallImagesCanStillZoomIn(imageSize: CGSize) {
        let scrollView = Self.scrollView(imageSize: imageSize)

        #expect(Self.maximum(for: scrollView) == Self.unsafeFrame.zoomScaleToFit(scrollView.imageSize) * 2)
    }

    @Test("A small image zooms to twice the size that fills the frame")
    func smallImageZoomsToTwiceFittedSize() {
        /// A 60 point square fills a 393 point wide frame at 6.55, so it can zoom to 13.1.
        #expect(Self.maximum(for: Self.scrollView(imageSize: .init(width: 60, height: 60))) == 13.1)
    }

    @Test("A requested maximum above twice the fitted scale is used as is", arguments: largeSizes)
    func largerRequestedMaximumIsUsedAsIs(imageSize: CGSize) {
        #expect(Self.maximum(for: Self.scrollView(imageSize: imageSize, maximumZoomScale: 100)) == 100)
    }

    /// A new `UIScrollView` starts with a minimum and a maximum zoom scale of 1. An image that fits at a scale of 1, such as a screenshot taken on the same device, matches that minimum, so a layout that went by the minimum alone left it with the default maximum and unable to zoom in.
    @Test("An image that fits at a scale of 1 still has its zoom scales applied")
    func imageFittingAtOneStillGetsItsZoomScales() {
        let scrollView = Self.scrollView(imageSize: frame)
        scrollView.frame = CGRect(origin: .zero, size: frame)
        scrollView.layoutIfNeeded()

        #expect(scrollView.minimumZoomScale == 1)
        #expect(scrollView.maximumZoomScale == 2)
    }
}

/// The frame a viewer is laid out in changes size when an ``AutoRotatingView`` turns it, and SwiftUI animates that change frame by frame while only updating the representable once, at the start. The scroll view has to lay its image out from whatever bounds it currently has, or the image jumps to the layout it will end at and then slides back into place as the frame catches up.
@MainActor
@Suite("ZoomImageScrollView resizing")
struct ScrollViewResizeTests {
    /// A portrait phone's safe area, as SwiftUI reports it when nothing is rotated.
    static let portraitInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

    /// The same safe area inside a view rotated a quarter turn.
    static let rotatedInsets = UIEdgeInsets(top: 0, left: 34, bottom: 0, right: 59)

    /// A landscape frame, as the same phone is laid out after a quarter turn.
    static let landscapeFrame = CGSize(width: frame.height, height: frame.width)

    /// A frame part way through a quarter turn, neither the size it started at nor the one it ends at.
    static let partWayThroughFrame = CGSize(width: 600, height: 645)

    /// Zooming is what keeps `contentSize` up to date, and that needs a delegate to say which view to zoom. `UIScrollView` only holds a weak one, so tests keep it alive alongside the scroll view.
    final class ZoomDelegate: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomImageScrollView)?.imageView
        }
    }

    /// A scroll view laid out as SwiftUI first presents one: told its frame, then given bounds of that size.
    static func scrollView(imageSize: CGSize, safeAreaInsets: UIEdgeInsets = .zero, delegate: ZoomDelegate) -> ZoomImageScrollView {
        let scrollView = ZoomImageScrollView(image: ScrollViewZoomScaleTests.image(size: imageSize), maximumZoomScale: requestedMaximumZoomScale)
        scrollView.delegate = delegate
        scrollView.setTargetFrame(SafeAreaFrame(size: frame, safeAreaInsets: safeAreaInsets))
        scrollView.frame = CGRect(origin: .zero, size: frame)
        scrollView.layoutIfNeeded()
        return scrollView
    }

    /// Moves the bounds `progress` of the way through a quarter turn from portrait to landscape, as SwiftUI does on one frame of the animation.
    static func setBounds(of scrollView: ZoomImageScrollView, progress: CGFloat) {
        scrollView.bounds.size = CGSize(
            width: frame.width.interpolated(to: landscapeFrame.width, progress: progress),
            height: frame.height.interpolated(to: landscapeFrame.height, progress: progress)
        )
        scrollView.layoutIfNeeded()
    }

    /// The point of the image, before any zoom, that the scroll view is showing in the middle of its safe area.
    static func centredImagePoint(in scrollView: ZoomImageScrollView) -> CGPoint {
        (scrollView.contentOffset + scrollView.layoutFrame.safeCentre) / scrollView.zoomScale
    }

    /// How far, in points on screen, the image is from showing `imagePoint` in the middle of the safe area.
    ///
    /// Measured on screen rather than in the image, as the same drift in image coordinates is a different amount of movement at every zoom scale, and `UIScrollView` rounds its content to whole pixels either way.
    static func offsetOnScreen(of imagePoint: CGPoint, from scrollView: ZoomImageScrollView) -> CGPoint {
        (centredImagePoint(in: scrollView) - imagePoint) * scrollView.zoomScale
    }

    @Test("A zoomed out image is fitted to the bounds it is given", arguments: largeSizes + smallSizes)
    func fitsToBounds(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)

        #expect(abs(scrollView.zoomScale - imageSize.zoomScaleToFit(frame)) < 0.0001)
    }

    /// A tall and skinny image used to open fitted to the whole frame, leaving its ends under the status bar and home indicator.
    @Test("An image opens fitted and centred inside the safe area")
    func opensFittedInsideSafeArea() {
        let imageSize = CGSize(width: 141, height: 1573)
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, safeAreaInsets: Self.portraitInsets, delegate: delegate)

        let safeHeight = frame.height - Self.portraitInsets.top - Self.portraitInsets.bottom
        #expect(abs(scrollView.zoomScale - safeHeight / imageSize.height) < 0.0001)
        #expect(abs(scrollView.contentOffset.y + Self.portraitInsets.top) < 0.5)
    }

    /// Bounds SwiftUI never announced, such as a frame set directly, have no resize to follow, so the image is simply fitted to them.
    @Test("A zoomed out image is refitted when the bounds change unannounced", arguments: largeSizes + smallSizes)
    func refitsWhenBoundsChange(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)

        for size in [Self.partWayThroughFrame, Self.landscapeFrame] {
            scrollView.bounds.size = size
            scrollView.layoutIfNeeded()

            #expect(abs(scrollView.zoomScale - imageSize.zoomScaleToFit(size)) < 0.0001)
        }
    }

    /// A frame part way between portrait and landscape is closer to square than either and fits most images at a larger scale than both, so refitting on every frame of a rotation made the image grow and then shrink again. The scale has to move in a straight line from where the rotation started to where it ends, the way SwiftUI moves a frame.
    @Test("A zoomed out image scales in a straight line through a rotation", arguments: largeSizes + smallSizes)
    func scalesLinearlyThroughRotation(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, safeAreaInsets: Self.portraitInsets, delegate: delegate)
        let startScale = scrollView.zoomScale

        scrollView.setTargetFrame(SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: Self.rotatedInsets))
        let endFrame = SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: Self.rotatedInsets)
        let endScale = endFrame.zoomScaleToFit(scrollView.imageSize)

        for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
            Self.setBounds(of: scrollView, progress: progress)

            #expect(abs(scrollView.zoomScale - startScale.interpolated(to: endScale, progress: progress)) < 0.0001)
            #expect(scrollView.zoomScale <= max(startScale, endScale) + 0.0001)
        }
    }

    /// SwiftUI moves the safe area with the frame, so an image centred in it moves steadily rather than jumping when the insets change edges at the start of the rotation.
    @Test("The safe area moves in a straight line through a rotation")
    func safeAreaMovesLinearlyThroughRotation() {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: CGSize(width: 4000, height: 3000), safeAreaInsets: Self.portraitInsets, delegate: delegate)
        scrollView.setTargetFrame(SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: Self.rotatedInsets))

        Self.setBounds(of: scrollView, progress: 0.5)
        #expect(scrollView.layoutFrame.safeAreaInsets == Self.portraitInsets.interpolated(to: Self.rotatedInsets, progress: 0.5))

        Self.setBounds(of: scrollView, progress: 1)
        #expect(scrollView.layoutFrame.safeAreaInsets == Self.rotatedInsets)
    }

    @Test("A zoomed out image stays centred in the safe area through a rotation", arguments: largeSizes + smallSizes)
    func staysCentredThroughRotation(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, safeAreaInsets: Self.portraitInsets, delegate: delegate)
        scrollView.setTargetFrame(SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: Self.rotatedInsets))

        for progress: CGFloat in [0.25, 0.5, 1] {
            Self.setBounds(of: scrollView, progress: progress)

            let drift = Self.offsetOnScreen(of: CGPoint(cgSize: imageSize / 2), from: scrollView)
            #expect(abs(drift.x) < 0.5)
            #expect(abs(drift.y) < 0.5)
        }
    }

    /// Zooming in is the whole point of the viewer, so a rotation should not throw away where the person had got to.
    @Test("A zoomed in image keeps the part of it that was in the middle")
    func zoomedInImageKeepsItsCentre() {
        let imageSize = CGSize(width: 4000, height: 3000)
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)
        scrollView.zoomScale = scrollView.maximumZoomScale
        let centre = CGPoint(x: 1000, y: 500)
        scrollView.contentOffset = centre * scrollView.zoomScale - CGPoint(cgSize: frame / 2)

        scrollView.setTargetFrame(SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: .zero))
        Self.setBounds(of: scrollView, progress: 1)

        let drift = Self.offsetOnScreen(of: centre, from: scrollView)
        #expect(abs(drift.x) < 0.5)
        #expect(abs(drift.y) < 0.5)
    }

    /// A zoomed in image keeps its scale through a resize, rather than being refitted as if it had been left zoomed out.
    @Test("A zoomed in image keeps its zoom scale")
    func zoomedInImageKeepsItsZoomScale() {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: CGSize(width: 4000, height: 3000), delegate: delegate)
        scrollView.zoomScale = 1

        scrollView.setTargetFrame(SafeAreaFrame(size: Self.landscapeFrame, safeAreaInsets: .zero))
        Self.setBounds(of: scrollView, progress: 0.5)
        Self.setBounds(of: scrollView, progress: 1)

        #expect(scrollView.zoomScale == 1)
    }
}
