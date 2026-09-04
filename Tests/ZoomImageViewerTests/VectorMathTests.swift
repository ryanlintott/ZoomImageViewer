//
//  VectorMathTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-04.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

@Suite("Vector normalization")
struct VectorMathTests {
    /// Dragging an image away divides the drag by its own length, which used to give a size of
    /// `NaN` for a vector with no length.
    @Test("A size with no length normalizes to zero")
    func zeroSizeNormalizesToZero() {
        #expect(CGSize.zero.normalized == .zero)
    }

    @Test("A point with no length normalizes to zero")
    func zeroPointNormalizesToZero() {
        #expect(CGPoint.zero.normalized == .zero)
    }

    @Test("A size keeps its direction and gains a length of 1")
    func sizeNormalizesToUnitLength() {
        let normalized = CGSize(width: 3, height: 4).normalized

        #expect(abs(normalized.magnitude - 1) < 0.0001)
        #expect(abs(normalized.width - 0.6) < 0.0001)
        #expect(abs(normalized.height - 0.8) < 0.0001)
    }

    @Test("A point keeps its direction and gains a length of 1")
    func pointNormalizesToUnitLength() {
        let normalized = CGPoint(x: 3, y: 4).normalized

        #expect(abs(normalized.magnitude - 1) < 0.0001)
        #expect(abs(normalized.x - 0.6) < 0.0001)
        #expect(abs(normalized.y - 0.8) < 0.0001)
    }
}

@Suite("ZoomState")
struct ZoomStateTests {
    @Test("The states are distinct")
    func statesAreDistinct() {
        #expect(ZoomState.min != .partial)
        #expect(ZoomState.min != .max(center: nil))
        #expect(ZoomState.partial != .max(center: nil))
    }

    /// Zooming out reports `max` with no centre while a double tap reports the point tapped, and
    /// `updateUIView` only zooms to a centre when one is given.
    @Test("Zoomed in states are told apart by their centre")
    func zoomedInStatesComparedByCentre() {
        #expect(ZoomState.max(center: nil) != .max(center: .zero))
        #expect(ZoomState.max(center: .init(x: 1, y: 2)) != .max(center: .init(x: 2, y: 1)))
        #expect(ZoomState.max(center: .init(x: 1, y: 2)) == .max(center: .init(x: 1, y: 2)))
        #expect(ZoomState.max(center: nil) == .max(center: nil))
    }
}
