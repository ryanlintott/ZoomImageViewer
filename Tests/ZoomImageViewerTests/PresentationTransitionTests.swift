//
//  PresentationTransitionTests.swift
//  ZoomImageViewerTests
//
//  Created by Ryan Lintott on 2026-09-21.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

@MainActor
@Suite("Presentation transition")
struct PresentationTransitionTests {
    private let fadeDuration: TimeInterval = 0.4

    @Test("Opening uses matched geometry unless Reduce Motion is enabled")
    func openingTransition() {
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: Namespace().wrappedValue
        )

        #expect(ZoomImagePresentationTransition.opening(
            matchedGeometry: matchedGeometry,
            reduceMotion: false
        ) == .matched(matchedGeometry))
        #expect(ZoomImagePresentationTransition.opening(
            matchedGeometry: matchedGeometry,
            reduceMotion: true
        ) == .fade)
        #expect(ZoomImagePresentationTransition.opening(
            matchedGeometry: nil,
            reduceMotion: false
        ) == .fade)
    }

    @Test("Fade keeps the image until the viewer has faded")
    func fadeProperties() {
        let transition = ZoomImagePresentationTransition.fade

        #expect(transition.matchedGeometry == nil)
        #expect(transition.keepsImageDuringDismissal)
        #expect(transition.settlingDuration(fadeDuration: fadeDuration) == fadeDuration)
    }

    @Test("Matched transition retains its geometry and settling duration")
    func matchedProperties() {
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: Namespace().wrappedValue
        )
        let transition = ZoomImagePresentationTransition.matched(matchedGeometry)

        #expect(transition.matchedGeometry == matchedGeometry)
        #expect(transition.keepsImageDuringDismissal == false)
        #expect(transition.settlingDuration(fadeDuration: fadeDuration) == ZoomImageMatchedGeometry.settlingDuration)
    }

    @Test("Toss keeps the image for its own duration")
    func tossProperties() {
        let toss = DismissToss(
            offset: CGSize(width: 20, height: 40),
            velocity: CGSize(width: 100, height: 200),
            predictedEndTranslation: CGSize(width: 40, height: 80),
            minimumDistance: 400,
            duration: 0.6
        )
        let transition = ZoomImagePresentationTransition.toss(toss)

        #expect(transition.matchedGeometry == nil)
        #expect(transition.keepsImageDuringDismissal)
        #expect(transition.settlingDuration(fadeDuration: fadeDuration) == toss.duration)
    }
}
