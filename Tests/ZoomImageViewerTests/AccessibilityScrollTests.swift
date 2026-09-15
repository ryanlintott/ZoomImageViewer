//
//  AccessibilityScrollTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points, including its safe area.
private let frame = CGSize(width: 393, height: 852)

/// A portrait phone's safe area.
private let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

/// The size of the safe area.
private let safeSize = CGSize(width: 393, height: 759)

/// The step `ZoomImageViewRepresentable` scrolls by, half the safe area.
private let step = safeSize / 2

@MainActor
@Suite("Accessibility scrolling")
struct AccessibilityScrollTests {
    /// A scroll view showing an image zoomed to twice the size of the safe area, scrolled to its top left corner.
    static func zoomedScrollView() -> ZoomImageScrollView {
        let scrollView = ZoomImageScrollView(image: UIImage(), maximumZoomScale: 2)
        scrollView.setTargetFrame(SafeAreaFrame(size: frame, safeAreaInsets: insets))
        scrollView.frame = CGRect(origin: .zero, size: frame)
        scrollView.layoutIfNeeded()
        scrollView.contentSize = safeSize * 2
        scrollView.updateInset()
        scrollView.contentOffset = CGPoint(x: -insets.left, y: -insets.top)
        return scrollView
    }
    
    @Test("Each step scrolls by the distance given")
    func stepIsHalfTheSafeArea() {
        let scrollView = Self.zoomedScrollView()
        let start = scrollView.contentOffset
        
        #expect(scrollView.contentOffset(scrollingTowards: .bottom, by: step) == CGPoint(x: start.x, y: start.y + safeSize.height / 2))
        #expect(scrollView.contentOffset(scrollingTowards: .right, by: step) == CGPoint(x: start.x + safeSize.width / 2, y: start.y))
    }
    
    @Test("Scrolling stops at the edges of the image")
    func stepStopsAtEdges() {
        let scrollView = Self.zoomedScrollView()
        let start = scrollView.contentOffset
        
        #expect(scrollView.contentOffset(scrollingTowards: .top, by: step) == start)
        #expect(scrollView.contentOffset(scrollingTowards: .left, by: step) == start)
        
        scrollView.contentOffset = scrollView.contentOffset(scrollingTowards: .bottom, by: step)
        scrollView.contentOffset = scrollView.contentOffset(scrollingTowards: .bottom, by: step)
        #expect(scrollView.contentOffset.y == safeSize.height * 2 + insets.bottom - frame.height)
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
