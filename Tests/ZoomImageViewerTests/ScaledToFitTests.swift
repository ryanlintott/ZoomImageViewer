//
//  ScaledToFitTests.swift
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
