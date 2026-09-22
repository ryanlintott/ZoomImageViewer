//
//  PresentationStateTests.swift
//  ZoomImageViewerTests
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

@MainActor
@Suite("Presentation state")
struct PresentationStateTests {
    static func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
    }

    static func matchedGeometry(id: Int = 1) -> ZoomImageMatchedGeometry {
        ZoomImageMatchedGeometry(
            id: AnyHashable(id),
            namespace: Namespace().wrappedValue
        )
    }

    @Test("An image starts in an appearing phase")
    func imageStartsAppearing() {
        let image = Self.image()
        let state = ZoomImagePresentationState(
            image: image,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )

        #expect(state.image === image)
        #expect(state.phase == .appearing)
        #expect(state.isOpening)
        #expect(state.isDismissing == false)
        guard case .fade = state.transition else {
            Issue.record("Expected the opening transition to be retained.")
            return
        }
    }

    @Test("An empty state starts hidden without source geometry")
    func emptyStateStartsHidden() {
        let namespace = Namespace().wrappedValue
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: namespace
        )
        let state = ZoomImagePresentationState(
            image: nil,
            openingTransition: .matched(matchedGeometry),
            availableMatchedGeometry: matchedGeometry
        )

        #expect(state.image == nil)
        #expect(state.phase == .hidden)
        #expect(state.availableMatchedGeometry == nil)
        guard case .fade = state.transition else {
            Issue.record("Expected an empty presentation to use a fade transition.")
            return
        }
    }

    @Test("Phase predicates follow the current phase")
    func phasePredicatesFollowPhase() {
        var state = ZoomImagePresentationState(
            image: Self.image(),
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )

        #expect(state.isOpening)
        #expect(state.isDismissing == false)

        state.phase = .presented
        #expect(state.isOpening == false)
        #expect(state.isDismissing == false)

        state.phase = .dismissing
        #expect(state.isOpening == false)
        #expect(state.isDismissing)

        state.phase = .hidden
        #expect(state.isOpening == false)
        #expect(state.isDismissing == false)
    }

    @Test("A first matched request renders in its source-removal transaction")
    func firstMatchedRequestRendersImmediately() {
        let image = Self.image()
        let matchedGeometry = Self.matchedGeometry()
        let state = ZoomImagePresentationState(
            image: nil,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )
        let request = ZoomImagePresentationRequest(
            image: image,
            matchedGeometry: matchedGeometry,
            reduceMotion: false
        )

        #expect(state.matchedGeometry(for: request) == matchedGeometry)
        #expect(state.presentedImage(for: request) === image)
        #expect(state.isShowingImage(for: request))
    }

    @Test("A first fade request waits for reconciliation")
    func firstFadeRequestWaitsForReconciliation() {
        let request = ZoomImagePresentationRequest(
            image: Self.image(),
            matchedGeometry: nil,
            reduceMotion: false
        )
        let state = ZoomImagePresentationState(
            image: nil,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )

        #expect(state.matchedGeometry(for: request) == nil)
        #expect(state.presentedImage(for: request) == nil)
        #expect(state.isShowingImage(for: request))
    }

    @Test("A running opening retains its matched geometry")
    func openingRetainsMatchedGeometry() {
        let image = Self.image()
        let openingGeometry = Self.matchedGeometry(id: 1)
        let newerGeometry = Self.matchedGeometry(id: 2)
        let state = ZoomImagePresentationState(
            image: image,
            openingTransition: .matched(openingGeometry),
            availableMatchedGeometry: openingGeometry
        )
        let request = ZoomImagePresentationRequest(
            image: image,
            matchedGeometry: newerGeometry,
            reduceMotion: true
        )

        #expect(state.matchedGeometry(for: request) == openingGeometry)
    }

    @Test("A presented image samples source and Reduce Motion for the next transition")
    func presentedImageSamplesCurrentRequest() {
        let image = Self.image()
        let previousGeometry = Self.matchedGeometry(id: 1)
        let currentGeometry = Self.matchedGeometry(id: 2)
        var state = ZoomImagePresentationState(
            image: image,
            openingTransition: .matched(previousGeometry),
            availableMatchedGeometry: previousGeometry
        )
        state.phase = .presented

        let matchedRequest = ZoomImagePresentationRequest(
            image: image,
            matchedGeometry: currentGeometry,
            reduceMotion: false
        )
        let reducedMotionRequest = ZoomImagePresentationRequest(
            image: image,
            matchedGeometry: currentGeometry,
            reduceMotion: true
        )

        #expect(state.matchedGeometry(for: matchedRequest) == currentGeometry)
        #expect(state.dismissalMatchedGeometry(for: matchedRequest) == currentGeometry)
        #expect(state.matchedGeometry(for: reducedMotionRequest) == nil)
        #expect(state.dismissalMatchedGeometry(for: reducedMotionRequest) == nil)
    }

    @Test("A running dismissal retains its plan and the right image hierarchy")
    func dismissalRetainsPlanAndHierarchy() {
        let image = Self.image()
        let matchedGeometry = Self.matchedGeometry()
        let emptyRequest = ZoomImagePresentationRequest(
            image: nil,
            matchedGeometry: nil,
            reduceMotion: true
        )
        var state = ZoomImagePresentationState(
            image: image,
            openingTransition: .fade,
            availableMatchedGeometry: matchedGeometry
        )
        state.phase = .dismissing
        state.transition = .matched(matchedGeometry)

        #expect(state.matchedGeometry(for: emptyRequest) == matchedGeometry)
        #expect(state.presentedImage(for: emptyRequest) === image)
        #expect(state.isShowingImage(for: emptyRequest) == false)

        state.transition = .fade
        #expect(state.matchedGeometry(for: emptyRequest) == nil)
        #expect(state.isShowingImage(for: emptyRequest))
    }

    @Test("A replacement does not inherit the outgoing drag offset")
    func replacementDropsOutgoingOffset() {
        let outgoingImage = Self.image()
        let replacementImage = Self.image()
        let dragOffset = CGSize(width: 40, height: 80)
        var state = ZoomImagePresentationState(
            image: outgoingImage,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )
        state.phase = .dismissing
        state.dragOffset = dragOffset

        let emptyRequest = ZoomImagePresentationRequest(
            image: nil,
            matchedGeometry: nil,
            reduceMotion: false
        )
        let replacementRequest = ZoomImagePresentationRequest(
            image: replacementImage,
            matchedGeometry: nil,
            reduceMotion: false
        )

        #expect(state.presentationOffset(for: emptyRequest) == dragOffset)
        #expect(state.presentationOffset(for: replacementRequest) == .zero)
    }

    @Test("Resetting interaction restores independent interaction values")
    func resetInteraction() {
        let image = Self.image()
        var state = ZoomImagePresentationState(
            image: image,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )
        state.dragOffset = CGSize(width: 40, height: 20)
        state.predictedEndTranslation = CGSize(width: 80, height: 30)
        state.dragVelocity = CGSize(width: 100, height: 50)
        state.zoomState = .max(center: .zero)
        state.isZoomedIn = true
        state.isShowingOverlay = false
        state.isInteractive = false
        state.accessibilityScrollRequest = AccessibilityScrollRequest(edge: .left)

        state.resetInteraction()

        #expect(state.image === image)
        #expect(state.phase == .appearing)
        #expect(state.dragOffset == .zero)
        #expect(state.predictedEndTranslation == .zero)
        #expect(state.dragVelocity == nil)
        #expect(state.zoomState == .min)
        #expect(state.isZoomedIn == false)
        #expect(state.isShowingOverlay)
        #expect(state.isInteractive)
        #expect(state.accessibilityScrollRequest == nil)
    }

    @Test("Resetting appearance clears only opacity targets")
    func resetAppearance() {
        let image = Self.image()
        var state = ZoomImagePresentationState(
            image: image,
            openingTransition: .fade,
            availableMatchedGeometry: nil
        )
        state.backgroundOpacity = 1
        state.imageOpacity = 0.5
        state.overlayOpacity = 0.25
        state.dragOffset = CGSize(width: 10, height: 20)

        state.resetAppearance()

        #expect(state.image === image)
        #expect(state.backgroundOpacity == .zero)
        #expect(state.imageOpacity == .zero)
        #expect(state.overlayOpacity == .zero)
        #expect(state.dragOffset == CGSize(width: 10, height: 20))
    }
}
