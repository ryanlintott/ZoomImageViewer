//
//  ZoomImagePresentationState.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// The complete mutable state of one zoom image viewer presentation.
///
/// The external binding is the requested presentation. This state owns what is actually on screen,
/// including an image retained while it dismisses. Its fields stay shallow so the views coordinating
/// a transition can read and update the complete operation in one place.
struct ZoomImagePresentationState {
    /// Where the retained image is in its visible lifetime.
    enum Phase {
        case hidden
        case appearing
        case presented
        case dismissing
    }

    var phase: Phase
    /// Identifies the current asynchronous phase so an obsolete completion cannot alter a newer presentation.
    var phaseID = UUID()

    var image: UIImage?
    /// The last source match known while the binding held an image.
    var availableMatchedGeometry: ZoomImageMatchedGeometry?
    /// How the current appearance or dismissal moves. Latched while either transition is running.
    var transition: ZoomImagePresentationTransition
    /// Exists before an image is inserted and stays stable until a completed dismissal, so SwiftUI sees one canvas throughout the matched transition.
    var canvasID = UUID()

    var zoomState: ZoomState = .min
    var isZoomedIn = false
    var isShowingOverlay = true
    var isInteractive = true

    var dragOffset: CGSize = .zero
    var predictedEndTranslation: CGSize = .zero
    var dragVelocity: CGSize?

    var backgroundOpacity: Double = .zero
    var imageOpacity: Double = .zero
    var overlayOpacity: Double = .zero

    var accessibilityScrollRequest: AccessibilityScrollRequest?

    init(
        image: UIImage?,
        openingTransition: ZoomImagePresentationTransition,
        availableMatchedGeometry: ZoomImageMatchedGeometry?
    ) {
        self.image = image
        if image == nil {
            phase = .hidden
            transition = .fade
            self.availableMatchedGeometry = nil
        } else {
            phase = .appearing
            transition = openingTransition
            self.availableMatchedGeometry = availableMatchedGeometry
        }
    }

    var isOpening: Bool {
        phase == .appearing
    }

    var isDismissing: Bool {
        phase == .dismissing
    }

    /// The source geometry used to render the current presentation request.
    ///
    /// An active transition retains the geometry it began with. Outside a transition, the latest
    /// resolved source and Reduce Motion setting determine whether the image uses matched geometry.
    func matchedGeometry(for request: ZoomImagePresentationRequest) -> ZoomImageMatchedGeometry? {
        if request.image != nil {
            if isOpening {
                return transition.matchedGeometry
            }
            guard !request.reduceMotion else { return nil }
            return request.matchedGeometry
        }

        if isDismissing {
            return transition.matchedGeometry
        }

        guard !request.reduceMotion else { return nil }
        return availableMatchedGeometry
    }

    /// The source eligible for a dismissal beginning with `request`.
    func dismissalMatchedGeometry(for request: ZoomImagePresentationRequest) -> ZoomImageMatchedGeometry? {
        guard !request.reduceMotion else { return nil }
        return request.matchedGeometry ?? availableMatchedGeometry
    }

    /// The image around which the viewer should currently be built.
    ///
    /// A matched presentation can use the newly requested image in the transaction that removes
    /// its source. Other presentations wait until the request has been reconciled into retained state.
    func presentedImage(for request: ZoomImagePresentationRequest) -> UIImage? {
        matchedGeometry(for: request) == nil ? image : image ?? request.image
    }

    /// Whether the fullscreen image itself should remain in the hierarchy.
    func isShowingImage(for request: ZoomImagePresentationRequest) -> Bool {
        let transition = matchedGeometry(for: request).map(ZoomImagePresentationTransition.matched) ?? .fade
        return request.image != nil || transition.keepsImageDuringDismissal
    }

    /// How far the retained image should be drawn from the middle of the frame.
    ///
    /// A replacement does not inherit the outgoing image's dismissal offset.
    func presentationOffset(for request: ZoomImagePresentationRequest) -> CGSize {
        if isDismissing, let requestedImage = request.image, requestedImage !== image {
            return .zero
        }
        return dragOffset
    }

    mutating func resetInteraction() {
        dragOffset = .zero
        predictedEndTranslation = .zero
        dragVelocity = nil
        zoomState = .min
        isZoomedIn = false
        isShowingOverlay = true
        accessibilityScrollRequest = nil
        isInteractive = true
    }

    mutating func resetAppearance() {
        backgroundOpacity = .zero
        imageOpacity = .zero
        overlayOpacity = .zero
    }
}
