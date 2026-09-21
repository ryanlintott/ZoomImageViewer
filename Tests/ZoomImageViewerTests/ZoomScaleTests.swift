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

/// The maximum zoom scale `ZoomImageViewerHost` requests.
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
        scrollView.clampedMaximumZoomScale(minimumZoomScale: scrollView.imageSize.zoomScaleToFit(frame))
    }

    /// A minimum zoom scale above the maximum leaves `UIScrollView` unable to zoom, and showing the image too small to fill the frame. `UIImage()` has no size, which used to give an infinite minimum zoom scale.
    @Test("An image with no size gets usable zoom scales")
    func emptyImageGetsUsableZoomScales() {
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: requestedMaximumZoomScale)

        #expect(scrollView.imageSize.zoomScaleToFit(frame) == 1)
        #expect(Self.maximum(for: scrollView) == requestedMaximumZoomScale)
    }

    @Test("The maximum is never below the minimum", arguments: largeSizes + smallSizes)
    func maximumIsNeverBelowMinimum(imageSize: CGSize) {
        let scrollView = Self.scrollView(imageSize: imageSize)

        #expect(Self.maximum(for: scrollView) >= scrollView.imageSize.zoomScaleToFit(frame))
    }

    @Test("Images at least as large as the frame use the requested maximum", arguments: largeSizes)
    func largeImagesUseRequestedMaximum(imageSize: CGSize) {
        #expect(Self.maximum(for: Self.scrollView(imageSize: imageSize)) == requestedMaximumZoomScale)
    }

    @Test("Images smaller than the frame can still zoom in", arguments: smallSizes)
    func smallImagesCanStillZoomIn(imageSize: CGSize) {
        let scrollView = Self.scrollView(imageSize: imageSize)

        #expect(Self.maximum(for: scrollView) == scrollView.imageSize.zoomScaleToFit(frame) * 2)
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
    static func scrollView(imageSize: CGSize, delegate: ZoomDelegate) -> ZoomImageScrollView {
        let scrollView = ZoomImageScrollView(image: ScrollViewZoomScaleTests.image(size: imageSize), maximumZoomScale: requestedMaximumZoomScale)
        scrollView.delegate = delegate
        scrollView.setTargetSize(frame)
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

    /// The point of the image, before any zoom, that the scroll view is showing in its middle.
    static func centredImagePoint(in scrollView: ZoomImageScrollView) -> CGPoint {
        (scrollView.contentOffset + CGPoint(cgSize: scrollView.layoutSize / 2)) / scrollView.zoomScale
    }

    /// How far, in points on screen, the image is from showing `imagePoint` in the middle of the scroll view.
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

    /// Like in Photos, a tall and skinny image fills the whole height of the screen, running under the status bar and home indicator, rather than stopping at the safe area.
    @Test("An image opens fitted and centred in the whole frame")
    func opensFittedInWholeFrame() {
        let imageSize = CGSize(width: 141, height: 1573)
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)

        let fittedWidth = imageSize.width * frame.height / imageSize.height
        #expect(abs(scrollView.zoomScale - frame.height / imageSize.height) < 0.0001)
        #expect(abs(scrollView.contentOffset.y) < 0.5)
        #expect(abs(scrollView.contentOffset.x + (frame.width - fittedWidth) / 2) < 0.5)
    }

    /// An image the size of the frame fits at a scale of 1, which a new `UIScrollView` already has, so fitting it never zooms. `UIScrollView` only updates its content size when it zooms, so the content size stayed empty and centring that empty size put the image's top left corner in the middle of the screen.
    @Test("An image the size of the frame opens filling it")
    func exactFitImageFillsFrame() {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: frame, delegate: delegate)

        #expect(scrollView.zoomScale == 1)
        #expect(scrollView.contentSize == frame)
        #expect(scrollView.contentInset == .zero)
        #expect(scrollView.contentOffset == .zero)
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
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)
        let startScale = scrollView.zoomScale

        scrollView.setTargetSize(Self.landscapeFrame)
        let endScale = scrollView.imageSize.zoomScaleToFit(Self.landscapeFrame)

        for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
            Self.setBounds(of: scrollView, progress: progress)

            #expect(abs(scrollView.zoomScale - startScale.interpolated(to: endScale, progress: progress)) < 0.0001)
            #expect(scrollView.zoomScale <= max(startScale, endScale) + 0.0001)
        }
    }

    /// Matched geometry shrinks the frame back into its source without SwiftUI announcing a new size. A resize still remembered from an earlier rotation read that as part of the rotation, and kept the image at its full size as it landed.
    @Test("A zoomed out image is refitted to bounds changed after a rotation ends", arguments: largeSizes + smallSizes)
    func refitsAfterRotationEnds(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)
        scrollView.setTargetSize(Self.landscapeFrame)
        Self.setBounds(of: scrollView, progress: 0.5)
        Self.setBounds(of: scrollView, progress: 1)

        let thumbnail = CGSize(width: 80, height: 60)
        scrollView.bounds.size = thumbnail
        scrollView.layoutIfNeeded()

        #expect(abs(scrollView.zoomScale - imageSize.zoomScaleToFit(thumbnail)) < 0.0001)
    }

    @Test("A zoomed out image stays centred through a rotation", arguments: largeSizes + smallSizes)
    func staysCentredThroughRotation(imageSize: CGSize) {
        let delegate = ZoomDelegate()
        let scrollView = Self.scrollView(imageSize: imageSize, delegate: delegate)
        scrollView.setTargetSize(Self.landscapeFrame)

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

        scrollView.setTargetSize(Self.landscapeFrame)
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

        scrollView.setTargetSize(Self.landscapeFrame)
        Self.setBounds(of: scrollView, progress: 0.5)
        Self.setBounds(of: scrollView, progress: 1)

        #expect(scrollView.zoomScale == 1)
    }
}

/// The viewer hides its overlay, status bar and home indicator while the image is zoomed in, so only an image zoomed past the scale that fits it should count.
@MainActor
@Suite("ZoomImageScrollView zoomed in")
struct ScrollViewZoomedInTests {
    @Test("A fitted image is not zoomed in", arguments: largeSizes + smallSizes)
    func fittedImageIsNotZoomedIn(imageSize: CGSize) {
        let delegate = ScrollViewResizeTests.ZoomDelegate()
        let scrollView = ScrollViewResizeTests.scrollView(imageSize: imageSize, delegate: delegate)

        #expect(!scrollView.isZoomedIn)
    }

    @Test("An image zoomed in part way or all the way is zoomed in", arguments: [0.5, 1])
    func zoomedImageIsZoomedIn(progress: CGFloat) {
        let delegate = ScrollViewResizeTests.ZoomDelegate()
        let scrollView = ScrollViewResizeTests.scrollView(imageSize: CGSize(width: 4000, height: 3000), delegate: delegate)
        scrollView.zoomScale = scrollView.minimumZoomScale.interpolated(to: scrollView.maximumZoomScale, progress: progress)

        #expect(scrollView.isZoomedIn)
    }

    /// A pinch rarely settles on exactly the minimum it was clamped to.
    @Test("An image a hair above the fitted scale is not zoomed in")
    func imageWithinToleranceIsNotZoomedIn() {
        let delegate = ScrollViewResizeTests.ZoomDelegate()
        let scrollView = ScrollViewResizeTests.scrollView(imageSize: CGSize(width: 4000, height: 3000), delegate: delegate)
        scrollView.zoomScale = scrollView.minimumZoomScale * 1.00001

        #expect(!scrollView.isZoomedIn)
    }

    /// The minimum zoom scale moves on every frame of a rotation, and the overlay would flicker if a zoomed out image ever looked zoomed in along the way.
    @Test("A zoomed out image is never zoomed in through a rotation", arguments: [0.25, 0.5, 0.75, 1])
    func zoomedOutImageStaysZoomedOutThroughARotation(progress: CGFloat) {
        let delegate = ScrollViewResizeTests.ZoomDelegate()
        let scrollView = ScrollViewResizeTests.scrollView(imageSize: CGSize(width: 4000, height: 3000), delegate: delegate)

        scrollView.setTargetSize(ScrollViewResizeTests.landscapeFrame)
        ScrollViewResizeTests.setBounds(of: scrollView, progress: progress)

        #expect(!scrollView.isZoomedIn)
    }
}
