//
//  CloseButtonPlacementTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-25.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

private typealias Placement = ZoomImageCloseButtonPlacement

/// Sizes, safe areas and reserved regions measured on the iPhone Duo simulator on iOS 27.1, where the system's close button on a fullscreen sheet was in the same place as the placement's.
@Suite("Close button placement")
struct CloseButtonPlacementTests {
    /// The camera at the top of the vertical bar on the folded iPhone Duo in portrait.
    private let camera = CGRect(x: 399.67, y: 29.33, width: 37, height: 37)

    @Test("Below the top of a vertical bar, centred where the system centres bar items")
    func belowAVerticalBar() {
        /// Folded, in portrait.
        let placement = Placement(
            position: nil,
            size: CGSize(width: 466, height: 678),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
            occlusionFrames: [camera, CGRect(x: 382, y: 0, width: 84, height: 170)]
        )

        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding.top == 170)
        #expect(placement.padding.trailing == 0)
        #expect(placement.slotWidth == 96, "Centred 48 points from the outer edge")
        #expect(placement.slotHeight == nil)
    }

    @Test("Follows a vertical bar on the other side, measured from that side's outer edge")
    func followsAVerticalBarOnTheOtherSide() {
        /// Folded, in landscape, with the camera at the top of the bar.
        let placement = Placement(
            position: nil,
            size: CGSize(width: 678, height: 466),
            safeAreaInsets: EdgeInsets(top: 0, leading: 84, bottom: 21, trailing: 0),
            occlusionFrames: [CGRect(x: 0, y: 0, width: 84, height: 82)]
        )

        #expect(placement.alignment == .topLeading)
        #expect(placement.padding.top == 82)
        #expect(placement.padding.leading == 0)
        #expect(placement.slotWidth == 96)
    }

    @Test("At least the bar's margin from the top where no system UI is at the top of the bar")
    func barMarginAtTheTop() {
        /// Folded, in landscape, with the camera at the bottom of the bar.
        let placement = Placement(
            position: nil,
            size: CGSize(width: 678, height: 466),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 21, trailing: 84),
            occlusionFrames: [CGRect(x: 594, y: 384, width: 84, height: 82)]
        )

        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding.top == 24)
        #expect(placement.padding.trailing == 0)
        #expect(placement.slotWidth == 96)
    }

    @Test("Beside system UI in a top corner, outside the safe area and centred 48 points from the top")
    func besideAHorizontalStatusBar() {
        /// Unfolded, in portrait.
        let placement = Placement(
            position: nil,
            size: CGSize(width: 669, height: 951),
            safeAreaInsets: EdgeInsets(top: 82, leading: 0, bottom: 34, trailing: 0),
            occlusionFrames: [CGRect(x: 535, y: 0, width: 134, height: 82)]
        )

        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding.top == 0)
        #expect(placement.padding.trailing == 134)
        #expect(placement.slotHeight == 96)
        #expect(placement.slotWidth == nil)
    }

    @Test("Concentric with a top corner that's clear, when the viewer is turned so the bar runs along the top")
    func concentricWithAClearCorner() {
        /// Folded, with the viewer turned to landscape by `AutoRotatingView` in an app that stays in portrait. The home indicator's inset on the trailing side isn't at the top, so the button doesn't avoid it.
        let placement = Placement(
            position: nil,
            size: CGSize(width: 678, height: 466),
            safeAreaInsets: EdgeInsets(top: 84, leading: 0, bottom: 0, trailing: 34),
            occlusionFrames: [
                CGRect(x: 29.33, y: 29.33, width: 37, height: 37),
                CGRect(x: 0, y: 0, width: 170, height: 84)
            ]
        )

        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding.top == 0)
        #expect(placement.padding.trailing == 0)
        #expect(placement.slotWidth == 96)
        #expect(placement.slotHeight == 96)
    }

    @Test("Padded from the safe area where the top inset isn't made by reserved regions")
    func paddedFromASafeAreaWithoutRegions() {
        let placement = Placement(
            position: nil,
            size: CGSize(width: 402, height: 874),
            safeAreaInsets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0),
            occlusionFrames: [CGRect(x: 138, y: 11, width: 126, height: 37)]
        )

        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 78, leading: 16, bottom: 50, trailing: 16))
        #expect(placement.slotWidth == nil)
        #expect(placement.slotHeight == nil)
    }

    @Test("A side inset without a reserved region as wide as it isn't a bar")
    func sideInsetWithoutARegionIsNotABar() {
        let bar = Placement.verticalBarEdge(
            size: CGSize(width: 678, height: 466),
            safeAreaInsets: EdgeInsets(top: 84, leading: 0, bottom: 0, trailing: 34),
            occlusionFrames: [CGRect(x: 0, y: 0, width: 170, height: 84)]
        )

        #expect(bar == nil)
    }

    @Test("A given position keeps its corner, clear of any system UI in it")
    func givenPositionStaysInItsCorner() {
        let size = CGSize(width: 669, height: 951)
        let safeAreaInsets = EdgeInsets(top: 82, leading: 0, bottom: 34, trailing: 0)
        let statusBar = CGRect(x: 535, y: 0, width: 134, height: 82)
        let topLeading = Placement(position: .topLeading, size: size, safeAreaInsets: safeAreaInsets, occlusionFrames: [statusBar])
        let topTrailing = Placement(position: .topTrailing, size: size, safeAreaInsets: safeAreaInsets, occlusionFrames: [statusBar])

        #expect(topLeading.alignment == .topLeading)
        #expect(topLeading.padding.top == 0)
        #expect(topLeading.padding.leading == 0)
        #expect(topLeading.slotWidth == 96)
        #expect(topTrailing.padding.trailing == 134)
    }

    @Test("A position along an edge is padded from the safe area")
    func edgePositionsIgnoreRegions() {
        let placement = Placement(
            position: .bottom,
            size: CGSize(width: 669, height: 951),
            safeAreaInsets: EdgeInsets(top: 82, leading: 0, bottom: 34, trailing: 0),
            occlusionFrames: [CGRect(x: 535, y: 0, width: 134, height: 82)]
        )

        #expect(placement.alignment == .bottom)
        #expect(placement.padding.bottom == 50)
        #expect(placement.slotWidth == nil)
        #expect(placement.slotHeight == nil)
    }
}
