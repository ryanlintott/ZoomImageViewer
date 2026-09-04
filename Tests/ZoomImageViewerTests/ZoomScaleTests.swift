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

/// The maximum zoom scale is a policy of the view rather than pure geometry, so it is checked
/// through the representable that applies it.
@MainActor
@Suite("ZoomImageViewRepresentable zoom scales")
struct RepresentableZoomScaleTests {
    /// An image of an exact size, drawn at a scale of 1 to keep the backing bitmap small.
    static func image(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in }
    }

    static func representable(
        imageSize: CGSize,
        maximumZoomScale: CGFloat = requestedMaximumZoomScale
    ) -> ZoomImageViewRepresentable {
        ZoomImageViewRepresentable(
            sizeIncludingSafeAreaInsets: frame,
            isInteractive: true,
            zoomState: .constant(.min),
            maximumZoomScale: maximumZoomScale,
            uiImage: image(size: imageSize)
        )
    }

    @Test("The minimum zoom scale is the scale needed to fit", arguments: largeSizes + smallSizes)
    func minimumIsScaleToFit(imageSize: CGSize) {
        #expect(Self.representable(imageSize: imageSize).minimumZoomScale == imageSize.zoomScaleToFit(frame))
    }

    /// A minimum zoom scale above the maximum leaves `UIScrollView` unable to zoom, and showing the
    /// image too small to fill the frame.
    /// `UIImage()` has no size, which used to give an infinite minimum zoom scale.
    @Test("An image with no size gets usable zoom scales")
    func emptyImageGetsUsableZoomScales() {
        let representable = ZoomImageViewRepresentable(
            sizeIncludingSafeAreaInsets: frame,
            isInteractive: true,
            zoomState: .constant(.min),
            maximumZoomScale: requestedMaximumZoomScale,
            uiImage: UIImage()
        )

        #expect(representable.minimumZoomScale == 1)
        #expect(representable.clampedMaximumZoomScale == requestedMaximumZoomScale)
    }

    @Test("The maximum is never below the minimum", arguments: largeSizes + smallSizes)
    func maximumIsNeverBelowMinimum(imageSize: CGSize) {
        let representable = Self.representable(imageSize: imageSize)

        #expect(representable.clampedMaximumZoomScale >= representable.minimumZoomScale)
    }

    @Test("Images at least as large as the frame use the requested maximum", arguments: largeSizes)
    func largeImagesUseRequestedMaximum(imageSize: CGSize) {
        #expect(Self.representable(imageSize: imageSize).clampedMaximumZoomScale == requestedMaximumZoomScale)
    }

    @Test("Images smaller than the frame can still zoom in", arguments: smallSizes)
    func smallImagesCanStillZoomIn(imageSize: CGSize) {
        let representable = Self.representable(imageSize: imageSize)

        #expect(representable.clampedMaximumZoomScale == representable.minimumZoomScale * 2)
    }

    @Test("A small image zooms to twice the size that fills the frame")
    func smallImageZoomsToTwiceFittedSize() {
        /// A 60 point square fills a 393 point wide frame at 6.55, so it can zoom to 13.1.
        #expect(Self.representable(imageSize: .init(width: 60, height: 60)).clampedMaximumZoomScale == 13.1)
    }

    @Test("A requested maximum above twice the fitted scale is used as is", arguments: largeSizes)
    func largerRequestedMaximumIsUsedAsIs(imageSize: CGSize) {
        #expect(Self.representable(imageSize: imageSize, maximumZoomScale: 100).clampedMaximumZoomScale == 100)
    }
}
