//
//  DismissTossTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

private let duration: TimeInterval = 0.4

/// A portrait phone's viewer, including its safe area.
private let bounds = CGRect(x: 0, y: 0, width: 402, height: 874)

/// The minimum distance `_ZoomImageView` asks for: twice the viewer's longest side.
private let minimumDistance: CGFloat = 874 * 2

/// A wide image fitted to the width of the viewer and centred vertically.
private let imageFrame = CGRect(x: 0, y: 286, width: 402, height: 302)

/// The image's velocity in points per second at the moment the toss starts.
private func startVelocity(of toss: DismissToss, from offset: CGSize) -> CGSize {
    (toss.endOffset - offset) * (toss.startSpeedFraction / duration)
}

/// Whether the image is completely outside the viewer once the toss has finished.
private func hasLeft(_ toss: DismissToss) -> Bool {
    let end = imageFrame.offsetBy(dx: toss.endOffset.width, dy: toss.endOffset.height)
    /// `CGRect.intersects` counts rects that only share an edge as separate, which is exactly the point where nothing of the image is left on screen.
    return !end.insetBy(dx: 0.001, dy: 0.001).intersects(bounds)
}

private func toss(offset: CGSize, velocity: CGSize?, predictedEndTranslation: CGSize) -> DismissToss {
    DismissToss(offset: offset, velocity: velocity, predictedEndTranslation: predictedEndTranslation, minimumDistance: minimumDistance, duration: duration)
}

@Suite("DismissToss")
struct DismissTossTests {
    /// The dismiss used to start from a spring whose velocity was worked out against the wrong distance and pointed from the image's resting place rather than the finger, so the image paused before it shot away.
    @Test("A throw starts at exactly the drag's velocity", arguments: [
        CGSize(width: 0, height: 4000),
        CGSize(width: -1800, height: 900),
        CGSize(width: 300, height: -300),
        CGSize(width: 0, height: 200)
    ])
    func throwKeepsVelocity(velocity: CGSize) {
        let offset = CGSize(width: 20, height: 150)
        let toss = toss(offset: offset, velocity: velocity, predictedEndTranslation: offset + velocity * 0.25)
        let start = startVelocity(of: toss, from: offset)

        #expect(abs(start.width - velocity.width) < 0.001)
        #expect(abs(start.height - velocity.height) < 0.001)
    }

    /// The image has to be gone by the time the background has faded, however it was thrown.
    @Test("The image always ends up off the screen", arguments: [
        (CGSize(width: 0, height: 250), CGSize(width: 0, height: 4000)),
        (CGSize(width: 0, height: 250), CGSize(width: 0, height: 100)),
        (CGSize(width: -30, height: -260), CGSize(width: -200, height: -900)),
        (CGSize(width: 220, height: 20), CGSize(width: 600, height: 0)),
        (CGSize(width: 150, height: 150), CGSize(width: 1, height: 1))
    ])
    func alwaysLeavesScreen(offset: CGSize, velocity: CGSize) {
        let toss = toss(offset: offset, velocity: velocity, predictedEndTranslation: offset + velocity * 0.25)

        #expect(hasLeft(toss))
    }

    /// Starting at the finger's speed and then speeding up would bring the delay back, so a throw that covers the minimum distance on its own is left alone.
    @Test("A throw fast enough to cover the minimum distance carries on at a constant speed")
    func fastThrowIsLinear() {
        let offset = CGSize(width: 0, height: 250)
        let velocity = CGSize(width: 0, height: 5000)
        let toss = toss(offset: offset, velocity: velocity, predictedEndTranslation: CGSize(width: 0, height: 1500))

        #expect(toss.startSpeedFraction == 1)
        #expect(toss.endOffset == CGSize(width: 0, height: 250 + 5000 * duration))
    }

    @Test("A slow throw speeds up to cover the minimum distance in time")
    func slowThrowSpeedsUpToMinimumDistance() {
        let offset = CGSize(width: 0, height: 250)
        let velocity = CGSize(width: 0, height: 400)
        let toss = toss(offset: offset, velocity: velocity, predictedEndTranslation: CGSize(width: 0, height: 350))

        #expect(toss.endOffset == CGSize(width: 0, height: 250 + minimumDistance))
        #expect(abs(toss.startSpeedFraction - 400 * duration / minimumDistance) < 0.0001)
    }

    /// An image dragged well away and then let go while drifting back still passes the dismiss threshold, and should leave the way it was dragged instead of flying back across the screen.
    @Test("Velocity leading back towards the middle is ignored")
    func velocityHeadingBackIsIgnored() {
        let offset = CGSize(width: 0, height: 500)
        let toss = toss(offset: offset, velocity: CGSize(width: 0, height: -300), predictedEndTranslation: CGSize(width: 0, height: 425))

        #expect(toss.startSpeedFraction == 0)
        #expect(toss.endOffset.height > offset.height)
        #expect(hasLeft(toss))
    }

    /// `DragGesture.Value.velocity` is only available from iOS 17.
    @Test("Without a velocity the image leaves the way the drag was heading")
    func missingVelocityUsesPredictedDirection() {
        let offset = CGSize(width: 300, height: 0)
        let toss = toss(offset: offset, velocity: nil, predictedEndTranslation: CGSize(width: 400, height: 0))

        #expect(toss.startSpeedFraction == 0)
        #expect(toss.endOffset.width > offset.width)
        #expect(toss.endOffset.height == 0)
        #expect(hasLeft(toss))
    }

    /// Checks the control points against SwiftUI's own evaluation of the same curve, rather than trusting the maths in the comment.
    @Test("The timing curve starts at the start speed fraction and ends at full speed", arguments: [0, 0.4, 1] as [CGFloat])
    func timingCurveSlopes(fraction: CGFloat) throws {
        guard #available(iOS 17, *) else { return }
        let curve = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 1 / 3, y: fraction / 3),
            endControlPoint: UnitPoint(x: 2 / 3, y: 2 / 3)
        )

        #expect(abs(curve.velocity(at: 0) - fraction) < 0.001)
        #expect(abs(curve.velocity(at: 1) - 1) < 0.001)
        #expect(abs(curve.value(at: 1) - 1) < 0.001)
    }
}
