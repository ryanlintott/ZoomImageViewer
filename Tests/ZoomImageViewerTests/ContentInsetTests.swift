//
//  ContentInsetTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-11.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points, including the safe area the image ignores.
private let frame = CGSize(width: 393, height: 852)

/// The content inset only centres the image, because `contentInsetAdjustmentBehavior` is `.never`. Like in Photos the image ignores the safe area, which `UIScrollView` would otherwise add from the window, on edges that are wrong whenever the content is rotated to an orientation the app does not support.
@MainActor
@Suite("ZoomImageScrollView content insets")
struct ContentInsetTests {
    static func scrollView(contentSize: CGSize) -> ZoomImageScrollView {
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: 2)
        scrollView.setTargetSize(frame)
        scrollView.frame = CGRect(origin: .zero, size: frame)
        scrollView.layoutIfNeeded()
        scrollView.contentSize = contentSize
        return scrollView
    }

    /// A zoomed in image can be scrolled right to the edges of the screen, under the status bar and home indicator.
    @Test("An image larger than the frame has no inset")
    func overflowingImageHasNoInset() {
        let scrollView = Self.scrollView(contentSize: CGSize(width: 800, height: 1600))
        scrollView.updateInset()

        #expect(scrollView.contentInset == .zero)
    }

    /// Like in Photos, a zoomed out image is centred in the whole frame rather than in the safe area.
    @Test("An image smaller than the frame is centred in it")
    func fittingImageIsCentredInFrame() {
        let contentSize = CGSize(width: 200, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        scrollView.updateInset()

        #expect(scrollView.contentInset.top == (frame.height - contentSize.height) / 2)
        #expect(scrollView.contentInset.bottom == (frame.height - contentSize.height) / 2)
        #expect(scrollView.contentInset.left == (frame.width - contentSize.width) / 2)
    }

    /// The insets add up to the whole frame, which is what stops an image that fits from being scrolled at all.
    @Test("An image smaller than the frame cannot be scrolled")
    func fittingImageCannotScroll() {
        let contentSize = CGSize(width: 200, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        scrollView.updateInset()

        let inset = scrollView.contentInset
        #expect(inset.top + contentSize.height + inset.bottom == frame.height)
        #expect(inset.left + contentSize.width + inset.right == frame.width)
    }

    /// Each axis is decided on its own, the same way `contentInsetAdjustmentBehavior` would.
    @Test("An image overflowing one axis has no inset there and is centred on the other")
    func axesAreDecidedSeparately() {
        let contentSize = CGSize(width: 800, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        scrollView.updateInset()

        #expect(scrollView.contentInset.left == 0)
        #expect(scrollView.contentInset.right == 0)
        #expect(scrollView.contentInset.top == (frame.height - contentSize.height) / 2)
    }

    /// An image fitted exactly to an axis lands a hair either side of it while a frame animates, so the inset has to settle on nothing smoothly rather than flicker between two values.
    @Test("The inset does not jump as an image grows past the frame", arguments: [-0.001, 0, 0.001])
    func insetIsContinuousAtFrameEdge(overflow: CGFloat) {
        let scrollView = Self.scrollView(contentSize: CGSize(width: 200, height: frame.height + overflow))
        scrollView.updateInset()

        #expect(abs(scrollView.contentInset.top) < 0.01)
        #expect(abs(scrollView.contentInset.bottom) < 0.01)
    }

    /// The inset is worked out from the scroll view's own bounds rather than a size handed in, so a frame animating to a new size stays centred at every step instead of only at the end.
    @Test("The inset follows the bounds, not the size the layout ended at")
    func insetFollowsBounds() {
        let contentSize = CGSize(width: 200, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        /// Part way through a quarter turn, between portrait and landscape.
        let partWayThrough = CGSize(width: 600, height: 645)
        scrollView.bounds.size = partWayThrough
        scrollView.updateInset()

        #expect(scrollView.contentInset.top == (partWayThrough.height - contentSize.height) / 2)
        #expect(scrollView.contentInset.left == (partWayThrough.width - contentSize.width) / 2)
    }

    /// Edge effects blur content along an edge the window picks, which inside a rotated viewer is an edge of the image rather than one under the status bar.
    @Test("Scroll edge effects are hidden")
    func edgeEffectsAreHidden() throws {
        guard #available(iOS 26, *) else { return }
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: 2)

        #expect(scrollView.topEdgeEffect.isHidden)
        #expect(scrollView.leftEdgeEffect.isHidden)
        #expect(scrollView.bottomEdgeEffect.isHidden)
        #expect(scrollView.rightEdgeEffect.isHidden)
    }
}
