//
//  LandingStartSpeedTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// How far an image dragged away from the middle of the frame moves as it lands back on its source.
private let move = CGSize(width: -60, height: -80)

/// The speed of an axis covered by half its distance every second, as a spring measures it.
private let halfEverySecond: CGFloat = 0.5

@Suite("Landing start speed")
struct LandingStartSpeedTests {
    @Test("A drag with no velocity sets off from a standstill")
    func dragWithoutVelocityStartsFromStandstill() {
        #expect(ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: nil) == .zero)
    }

    @Test("An axis with nowhere to move sets off from a standstill")
    func axisWithoutMoveStartsFromStandstill() {
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: CGSize(width: 0, height: -80), velocity: CGSize(width: 100, height: -40))

        #expect(speed.width == 0)
        #expect(speed.height != 0)
    }

    @Test("A drag heading the way the image lands carries on into the landing")
    func dragTowardsLandingCarriesOn() {
        /// Half of each axis every second.
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: CGSize(width: -30, height: -40))

        #expect(abs(speed.width - halfEverySecond) < 0.0001)
        #expect(abs(speed.height - halfEverySecond) < 0.0001)
    }

    @Test("A drag heading away from where the image lands follows through first")
    func dragAwayFromLandingFollowsThrough() {
        /// The opposite of the drag above, which is how every drag that throws an image away from its source reads.
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: CGSize(width: 30, height: 40))

        #expect(abs(speed.width + halfEverySecond) < 0.0001)
        #expect(abs(speed.height + halfEverySecond) < 0.0001)
    }

    @Test("A drag across the way the image lands keeps both of its axes")
    func dragAcrossLandingKeepsBothAxes() {
        /// At a right angle to the way the image lands, so a single speed along that line would be nothing at all.
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: CGSize(width: -80, height: 60))

        #expect(speed.width > 0)
        #expect(speed.height < 0)
    }

    @Test("A flick that barely moved the image is limited")
    func flickIsLimited() {
        /// A drag that covered both axes many times over every second, which without a limit would carry the image far past its source.
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: CGSize(width: -6000, height: -8000))

        #expect(abs(speed.width - ZoomImageMatchedGeometry.maximumStartSpeed) < 0.0001)
        #expect(abs(speed.height - ZoomImageMatchedGeometry.maximumStartSpeed) < 0.0001)
    }

    @Test("A limited flick still sets off the way it was thrown")
    func limitedFlickKeepsItsDirection() {
        /// Eight times as fast across as down, which the limit brings down without turning.
        let speed = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: CGSize(width: -6000, height: -1000))
        let unlimited = CGSize(width: -6000.0 / -60.0, height: -1000.0 / -80.0)

        #expect(abs(speed.width - ZoomImageMatchedGeometry.maximumStartSpeed) < 0.0001)
        #expect(abs(speed.width / speed.height - unlimited.width / unlimited.height) < 0.0001)
    }

    @Test("The start speed is measured against the distance the image moves")
    func startSpeedIsMeasuredAgainstDistance() {
        /// Twice as far to move at the same speed sets off at half the fraction of that distance.
        let velocity = CGSize(width: -30, height: -40)
        let near = ZoomImageMatchedGeometry.landingStartSpeed(move: move, velocity: velocity)
        let far = ZoomImageMatchedGeometry.landingStartSpeed(move: 2 * move, velocity: velocity)

        #expect(abs(far.width - near.width / 2) < 0.0001)
        #expect(abs(far.height - near.height / 2) < 0.0001)
    }
}
