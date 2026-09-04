//
//  ScaleToFitPaddingTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-03.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points.
private let frame = CGRect(x: 0, y: 0, width: 393, height: 852)

/// Image sizes with the same aspect ratio as the frame, leaving no padding at all.
private let exactFitSizes: [CGSize] = [
    .init(width: 393, height: 852),
    /// A screenshot taken on the same device.
    .init(width: 1179, height: 2556),
    .init(width: 131, height: 284)
]

/// Image sizes wider than the frame, leaving padding above and below.
private let wideSizes: [CGSize] = [
    .init(width: 4000, height: 3000),
    .init(width: 852, height: 393),
    /// Only just wider than the frame, leaving very thin bars.
    .init(width: 394, height: 852)
]

/// Image sizes taller than the frame, leaving padding on either side.
private let tallSizes: [CGSize] = [
    .init(width: 300, height: 1200),
    .init(width: 9, height: 100),
    /// Only just taller than the frame, leaving very thin bars.
    .init(width: 392, height: 852)
]

@Suite("ScaleToFitPadding")
struct ScaleToFitPaddingTests {
    /// The frame the image occupies once it has been scaled to fit and centred.
    static func imageFrame(for imageSize: CGSize, in rect: CGRect) -> CGRect {
        let size = imageSize.scaledToFit(rect.size)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Points on the scaled image: its centre and a point just inside each edge.
    ///
    /// Insets are proportional so they never land in a thin bar.
    static func pointsOnImage(for imageSize: CGSize, in rect: CGRect) -> [CGPoint] {
        let image = imageFrame(for: imageSize, in: rect)
        return [
            .init(x: image.midX, y: image.midY),
            .init(x: image.minX + image.width * 0.05, y: image.midY),
            .init(x: image.maxX - image.width * 0.05, y: image.midY),
            .init(x: image.midX, y: image.minY + image.height * 0.05),
            .init(x: image.midX, y: image.maxY - image.height * 0.05)
        ]
    }

    /// The midpoint of each padding bar, or no points when the image fills the frame.
    static func pointsOnPadding(for imageSize: CGSize, in rect: CGRect) -> [CGPoint] {
        let image = imageFrame(for: imageSize, in: rect)
        var points: [CGPoint] = []

        if image.minY > rect.minY {
            points.append(.init(x: rect.midX, y: (rect.minY + image.minY) / 2))
            points.append(.init(x: rect.midX, y: (image.maxY + rect.maxY) / 2))
        }

        if image.minX > rect.minX {
            points.append(.init(x: (rect.minX + image.minX) / 2, y: rect.midY))
            points.append(.init(x: (image.maxX + rect.maxX) / 2, y: rect.midY))
        }

        return points
    }

    @Test("The scaled image is never covered", arguments: exactFitSizes + wideSizes + tallSizes)
    func scaledImageIsNeverCovered(imageSize: CGSize) {
        let path = ScaleToFitPadding(size: imageSize).path(in: frame)

        for point in Self.pointsOnImage(for: imageSize, in: frame) {
            #expect(!path.contains(point), "\(point) is on the image and must stay interactive")
        }
    }

    @Test("The space around the image is covered", arguments: wideSizes + tallSizes)
    func spaceAroundImageIsCovered(imageSize: CGSize) {
        let path = ScaleToFitPadding(size: imageSize).path(in: frame)
        let points = Self.pointsOnPadding(for: imageSize, in: frame)

        #expect(!points.isEmpty)
        for point in points {
            #expect(path.contains(point), "\(point) is beside the image and must be covered")
        }
    }

    /// An image with the same aspect ratio as the frame used to produce a path covering the entire
    /// frame, which blocked every gesture including pinch, double tap and drag to dismiss.
    @Test("An image filling the frame is not covered at all", arguments: exactFitSizes)
    func imageFillingFrameIsNotCovered(imageSize: CGSize) {
        let path = ScaleToFitPadding(size: imageSize).path(in: frame)

        #expect(path.isEmpty)
    }

    @Test("A wide image is covered above and below only")
    func wideImageIsCoveredAboveAndBelowOnly() {
        let path = ScaleToFitPadding(size: .init(width: 4000, height: 3000)).path(in: frame)

        /// The image is 294.75 points tall and centred, leaving 278.625 point bars.
        #expect(path.contains(.init(x: frame.midX, y: 278)))
        #expect(!path.contains(.init(x: frame.midX, y: 280)))
        #expect(!path.contains(.init(x: frame.midX, y: 572)))
        #expect(path.contains(.init(x: frame.midX, y: 574)))
        /// The bars run the full width of the frame.
        #expect(path.contains(.init(x: frame.minX + 1, y: 1)))
        #expect(path.contains(.init(x: frame.maxX - 1, y: 1)))
        /// Nothing is covered beside the image.
        #expect(!path.contains(.init(x: frame.minX + 1, y: frame.midY)))
        #expect(!path.contains(.init(x: frame.maxX - 1, y: frame.midY)))
    }

    @Test("A tall image is covered on either side only")
    func tallImageIsCoveredOnEitherSideOnly() {
        let path = ScaleToFitPadding(size: .init(width: 300, height: 1200)).path(in: frame)

        /// The image is 213 points wide and centred, leaving 90 point bars.
        #expect(path.contains(.init(x: 89, y: frame.midY)))
        #expect(!path.contains(.init(x: 91, y: frame.midY)))
        #expect(!path.contains(.init(x: 302, y: frame.midY)))
        #expect(path.contains(.init(x: 304, y: frame.midY)))
        /// The bars run the full height of the frame.
        #expect(path.contains(.init(x: 1, y: frame.minY + 1)))
        #expect(path.contains(.init(x: 1, y: frame.maxY - 1)))
        /// Nothing is covered above or below the image.
        #expect(!path.contains(.init(x: frame.midX, y: frame.minY + 1)))
        #expect(!path.contains(.init(x: frame.midX, y: frame.maxY - 1)))
    }

    @Test("Padding is drawn relative to the rect origin")
    func paddingIsDrawnRelativeToRectOrigin() {
        let imageSize = CGSize(width: 4000, height: 3000)
        let rect = CGRect(x: 50, y: 100, width: frame.width, height: frame.height)
        let path = ScaleToFitPadding(size: imageSize).path(in: rect)

        #expect(rect.contains(path.boundingRect))
        for point in Self.pointsOnImage(for: imageSize, in: rect) {
            #expect(!path.contains(point))
        }
        for point in Self.pointsOnPadding(for: imageSize, in: rect) {
            #expect(path.contains(point))
        }
    }
}

@Suite("CGSize.scaledToFit")
struct CGSizeScaledToFitTests {
    @Test("An image wider than the frame is limited by the frame width")
    func widerImageIsLimitedByFrameWidth() {
        #expect(CGSize(width: 4000, height: 3000).scaledToFit(frame.size) == .init(width: 393, height: 294.75))
    }

    @Test("An image taller than the frame is limited by the frame height")
    func tallerImageIsLimitedByFrameHeight() {
        #expect(CGSize(width: 300, height: 1200).scaledToFit(frame.size) == .init(width: 213, height: 852))
    }

    @Test("An image matching the frame aspect ratio fills it", arguments: exactFitSizes)
    func matchingAspectRatioFillsFrame(imageSize: CGSize) {
        #expect(imageSize.scaledToFit(frame.size) == frame.size)
    }

    @Test("A zero size stays zero")
    func zeroSizeStaysZero() {
        #expect(CGSize.zero.scaledToFit(frame.size) == .zero)
    }

    @Test("The scaled size never exceeds the frame and keeps its aspect ratio", arguments: exactFitSizes + wideSizes + tallSizes)
    func scaledSizeNeverExceedsFrame(imageSize: CGSize) {
        let size = imageSize.scaledToFit(frame.size)

        #expect(size.width <= frame.width)
        #expect(size.height <= frame.height)
        #expect(abs(size.aspectRatio - imageSize.aspectRatio) < 0.0001)
    }
}
