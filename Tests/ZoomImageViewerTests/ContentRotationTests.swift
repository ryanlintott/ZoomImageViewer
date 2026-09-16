//
//  ContentRotationTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points.
private let frame = CGSize(width: 402, height: 874)

/// The transform of a view turned by `angle` around `anchor`, as a container like `AutoRotatingView` turns its content.
private func transform(rotatedBy angle: Angle, around anchor: CGPoint) -> CGAffineTransform {
    CGAffineTransform(translationX: anchor.x, y: anchor.y)
        .rotated(by: angle.radians)
        .translatedBy(x: -anchor.x, y: -anchor.y)
}

@Suite("Content rotation")
struct ContentRotationTests {
    @Test("A view square with its window has nothing to undo")
    func unrotatedViewIsNotRotated() {
        let rotation = ZoomImageContentRotation(transform: .identity, size: frame)

        #expect(!rotation.isRotated)
        #expect(rotation.angle == .zero)
        #expect(rotation.anchor == .center)
    }

    @Test("A view moved without being turned has nothing to undo")
    func offsetViewIsNotRotated() {
        let rotation = ZoomImageContentRotation(transform: CGAffineTransform(translationX: 40, y: -200), size: frame)

        #expect(!rotation.isRotated)
        #expect(rotation.anchor == .center)
    }

    @Test("A turned view reports the angle it is turned by", arguments: [-90.0, -45.0, 90.0, 180.0])
    func rotatedViewReportsItsAngle(degrees: Double) {
        let angle = Angle.degrees(degrees)
        let anchor = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let rotation = ZoomImageContentRotation(transform: transform(rotatedBy: angle, around: anchor), size: frame)

        #expect(rotation.isRotated)
        #expect(abs(rotation.angle.radians - angle.radians) < 0.0001)
    }

    @Test("A view turned around its middle reports its middle")
    func rotatedViewReportsCentreAnchor() {
        let anchor = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let rotation = ZoomImageContentRotation(transform: transform(rotatedBy: .degrees(90), around: anchor), size: frame)

        #expect(abs(rotation.anchor.x - 0.5) < 0.0001)
        #expect(abs(rotation.anchor.y - 0.5) < 0.0001)
    }

    @Test("A view turned around another point reports that point")
    func rotatedViewReportsOffsetAnchor() {
        /// Off centre in both directions, as the safe area a rotating container works around is rarely the same on opposite edges.
        let anchor = CGPoint(x: frame.width * 0.25, y: frame.height * 0.75)
        let rotation = ZoomImageContentRotation(transform: transform(rotatedBy: .degrees(-90), around: anchor), size: frame)

        #expect(abs(rotation.anchor.x - 0.25) < 0.0001)
        #expect(abs(rotation.anchor.y - 0.75) < 0.0001)
    }

    @Test("A view turned half way around reports the point it turns around")
    func halfTurnedViewReportsItsAnchor() {
        /// A half turn is the one rotation where every axis lands back on itself, so the point it turns around is the only thing separating it from a move.
        let anchor = CGPoint(x: frame.width * 0.4, y: frame.height * 0.6)
        let rotation = ZoomImageContentRotation(transform: transform(rotatedBy: .degrees(180), around: anchor), size: frame)

        #expect(rotation.isRotated)
        #expect(abs(rotation.anchor.x - 0.4) < 0.0001)
        #expect(abs(rotation.anchor.y - 0.6) < 0.0001)
    }

    @Test("A view with no size has nothing to undo", arguments: [CGSize.zero, CGSize(width: 402, height: 0), CGSize(width: 0, height: 874)])
    func viewWithoutSizeIsNotRotated(size: CGSize) {
        let rotation = ZoomImageContentRotation(transform: transform(rotatedBy: .degrees(90), around: .zero), size: size)

        #expect(!rotation.isRotated)
        #expect(rotation.anchor == .center)
    }
}
