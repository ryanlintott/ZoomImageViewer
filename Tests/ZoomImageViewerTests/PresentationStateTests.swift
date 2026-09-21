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

    @Test("Presenting the same image preserves its session")
    func sameImagePreservesSession() throws {
        let image = Self.image()
        var state = ZoomImagePresentationState(image: image, openingStyle: .fade, availableMatchedGeometry: nil)
        let sessionID = try #require(state.presentationID)

        let change = state.present(image, openingStyle: .fade, availableMatchedGeometry: nil)

        #expect(change == .unchanged)
        #expect(state.presentationID == sessionID)
    }

    @Test("Replacing the image resets interaction and starts a new session")
    func replacementStartsNewSession() throws {
        let firstImage = Self.image()
        let secondImage = Self.image()
        var state = ZoomImagePresentationState(image: firstImage, openingStyle: .fade, availableMatchedGeometry: nil)
        let firstSessionID = try #require(state.presentationID)
        let canvasID = state.canvasID
        state.drag.offset = CGSize(width: 40, height: 20)
        state.zoomState = .max(center: .zero)
        state.isShowingOverlay = false

        let change = state.present(secondImage, openingStyle: .fade, availableMatchedGeometry: nil)

        #expect(change == .replaced)
        #expect(state.presentationID != firstSessionID)
        #expect(state.canvasID == canvasID)
        #expect(state.displayedImage === secondImage)
        #expect(state.session?.isOpening == false)
        #expect(state.drag.offset == .zero)
        #expect(state.zoomState == .min)
        #expect(state.isShowingOverlay)
    }

    @Test("Canvas identity exists before insertion and spans a fade dismissal")
    func canvasIdentitySpansFadeDismissal() throws {
        var state = ZoomImagePresentationState(image: nil, openingStyle: .fade, availableMatchedGeometry: nil)
        let idleCanvasID = state.canvasID

        _ = state.present(Self.image(), openingStyle: .fade, availableMatchedGeometry: nil)
        #expect(state.canvasID == idleCanvasID)

        let proposedDismissalID = state.beginDismissal(style: .fade)
        let dismissalID = try #require(proposedDismissalID)
        #expect(state.canvasID == idleCanvasID)

        let didFinish = state.finishDismissal(id: dismissalID)
        #expect(didFinish)
        #expect(state.canvasID != idleCanvasID)
    }

    @Test("A matched removal prepares a fresh canvas only after dismissal begins")
    func matchedRemovalPreparesNextCanvasIdentity() throws {
        let namespace = Namespace().wrappedValue
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: namespace
        )
        var state = ZoomImagePresentationState(
            image: Self.image(),
            openingStyle: .matched(matchedGeometry),
            availableMatchedGeometry: matchedGeometry
        )
        let outgoingCanvasID = state.canvasID

        _ = state.beginDismissal(style: .matched(matchedGeometry))
        #expect(state.canvasID == outgoingCanvasID)

        state.prepareCanvasAfterMatchedRemoval()
        #expect(state.canvasID != outgoingCanvasID)
    }

    @Test("An opening plan remains latched until that opening finishes")
    func openingPlanIsLatched() throws {
        let image = Self.image()
        let namespace = Namespace().wrappedValue
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: namespace
        )
        var state = ZoomImagePresentationState(image: image, openingStyle: .fade, availableMatchedGeometry: nil)
        let sessionID = try #require(state.presentationID)

        let change = state.present(
            image,
            openingStyle: .matched(matchedGeometry),
            availableMatchedGeometry: matchedGeometry
        )

        #expect(change == .unchanged)
        #expect(state.availableMatchedGeometry == matchedGeometry)
        guard case .fade = state.session?.openingStyle else {
            Issue.record("Expected the fade opening to remain latched.")
            return
        }
        #expect(state.session?.isOpening == true)
        let didFinish = state.finishOpening(id: sessionID)
        #expect(didFinish)
        #expect(state.session?.isOpening == false)
    }

    @Test("A stale opening completion cannot alter an immediate replacement")
    func staleOpeningCompletionIsIgnored() throws {
        let firstImage = Self.image()
        var state = ZoomImagePresentationState(image: firstImage, openingStyle: .fade, availableMatchedGeometry: nil)
        let obsoleteSessionID = try #require(state.presentationID)

        _ = state.present(Self.image(), openingStyle: .fade, availableMatchedGeometry: nil)

        let didFinish = state.finishOpening(id: obsoleteSessionID)
        #expect(didFinish == false)
        #expect(state.session?.isOpening == false)
    }

    @Test("A source that appears before dismissal is retained for the next transition")
    func sourceCanBecomeAvailableBeforeDismissal() throws {
        let image = Self.image()
        let namespace = Namespace().wrappedValue
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: namespace
        )
        var state = ZoomImagePresentationState(image: image, openingStyle: .fade, availableMatchedGeometry: nil)

        let change = state.present(
            image,
            openingStyle: .matched(matchedGeometry),
            availableMatchedGeometry: matchedGeometry
        )

        #expect(change == .unchanged)
        #expect(state.availableMatchedGeometry == matchedGeometry)
    }

    @Test("A dismissal plan retains the source it began with")
    func dismissalPlanIsLatched() throws {
        let image = Self.image()
        let namespace = Namespace().wrappedValue
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: AnyHashable(1),
            namespace: namespace
        )
        var state = ZoomImagePresentationState(image: image, openingStyle: .matched(matchedGeometry), availableMatchedGeometry: matchedGeometry)
        let proposedDismissalID = state.beginDismissal(style: .matched(matchedGeometry))
        let dismissalID = try #require(proposedDismissalID)

        #expect(state.dismissalID == dismissalID)
        guard case .matched(let retainedMatch) = state.dismissal?.style else {
            Issue.record("Expected a matched dismissal to remain latched.")
            return
        }
        #expect(retainedMatch == matchedGeometry)
    }

    @Test("A stale cleanup cannot remove a newer presentation")
    func staleCleanupIsIgnored() throws {
        let image = Self.image()
        var state = ZoomImagePresentationState(image: image, openingStyle: .fade, availableMatchedGeometry: nil)
        let proposedDismissalID = state.beginDismissal(style: .fade)
        let obsoleteDismissalID = try #require(proposedDismissalID)

        #expect(state.present(Self.image(), openingStyle: .fade, availableMatchedGeometry: nil) == .replacedDuringDismissal)

        #expect(state.finishDismissal(id: obsoleteDismissalID) == false)
        #expect(state.displayedImage != nil)
        #expect(state.isDismissing == false)
    }

    @Test("Presenting the same image during dismissal resumes it in a new session")
    func sameImageResumesInNewSession() throws {
        let image = Self.image()
        var state = ZoomImagePresentationState(image: image, openingStyle: .fade, availableMatchedGeometry: nil)
        let firstSessionID = try #require(state.presentationID)
        _ = state.beginDismissal(style: .fade)

        let change = state.present(image, openingStyle: .fade, availableMatchedGeometry: nil)

        #expect(change == .resumed)
        #expect(state.presentationID != firstSessionID)
        #expect(state.isDismissing == false)
    }
}
