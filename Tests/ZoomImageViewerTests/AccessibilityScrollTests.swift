//
//  AccessibilityScrollTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points, including the safe area the image ignores.
private let frame = CGSize(width: 393, height: 852)

/// The step `ZoomImageViewRepresentable` scrolls by, half the frame.
private let step = frame / 2

@MainActor
@Suite("Accessibility scrolling")
struct AccessibilityScrollTests {
    /// A scroll view showing an image zoomed to twice the size of the frame, scrolled to its top left corner.
    static func zoomedScrollView() -> ZoomImageScrollView {
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: 2)
        scrollView.setTargetSize(frame)
        scrollView.frame = CGRect(origin: .zero, size: frame)
        scrollView.layoutIfNeeded()
        scrollView.contentSize = frame * 2
        scrollView.updateInset()
        scrollView.contentOffset = .zero
        return scrollView
    }
    
    @Test("Each step scrolls by the distance given")
    func stepIsHalfTheFrame() {
        let scrollView = Self.zoomedScrollView()
        let start = scrollView.contentOffset
        
        #expect(scrollView.contentOffset(scrollingTowards: .bottom, by: step) == CGPoint(x: start.x, y: start.y + frame.height / 2))
        #expect(scrollView.contentOffset(scrollingTowards: .right, by: step) == CGPoint(x: start.x + frame.width / 2, y: start.y))
    }
    
    @Test("Scrolling stops at the edges of the image")
    func stepStopsAtEdges() {
        let scrollView = Self.zoomedScrollView()
        let start = scrollView.contentOffset
        
        #expect(scrollView.contentOffset(scrollingTowards: .top, by: step) == start)
        #expect(scrollView.contentOffset(scrollingTowards: .left, by: step) == start)
        
        scrollView.contentOffset = scrollView.contentOffset(scrollingTowards: .bottom, by: step)
        scrollView.contentOffset = scrollView.contentOffset(scrollingTowards: .bottom, by: step)
        /// Scrolled to the very bottom of the image, with no safe area left below it.
        #expect(scrollView.contentOffset.y == frame.height * 2 - frame.height)
        #expect(scrollView.contentOffset(scrollingTowards: .bottom, by: step) == scrollView.contentOffset)
    }
    
    /// Horizontal edges from `accessibilityScrollAction(_:)` are the opposite side of the content to the one brought into view.
    @Test("Leading and trailing are resolved for the layout direction")
    func leadingAndTrailingFollowLayoutDirection() {
        #expect(UIRectEdge(accessibilityScrollEdge: .top, layoutDirection: .leftToRight) == .top)
        #expect(UIRectEdge(accessibilityScrollEdge: .bottom, layoutDirection: .rightToLeft) == .bottom)
        #expect(UIRectEdge(accessibilityScrollEdge: .leading, layoutDirection: .leftToRight) == .right)
        #expect(UIRectEdge(accessibilityScrollEdge: .trailing, layoutDirection: .leftToRight) == .left)
        #expect(UIRectEdge(accessibilityScrollEdge: .leading, layoutDirection: .rightToLeft) == .left)
        #expect(UIRectEdge(accessibilityScrollEdge: .trailing, layoutDirection: .rightToLeft) == .right)
    }
    
    @Test("Repeated requests towards the same edge are different requests")
    func repeatedRequestsAreDistinct() {
        #expect(AccessibilityScrollRequest(edge: .top) != AccessibilityScrollRequest(edge: .top))
    }
}
