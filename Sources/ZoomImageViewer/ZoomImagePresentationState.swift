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
/// including a session retained while it dismisses. Keeping those concerns separate lets a cleared
/// binding remove a matched image in the same transaction while the rest of the viewer finishes fading.
struct ZoomImagePresentationState {
    struct Session {
        enum OpeningStyle {
            case fade
            case matched(ZoomImageMatchedGeometry)
        }

        let id: UUID
        var image: UIImage
        let openingStyle: OpeningStyle
        var isOpening: Bool
        var availableMatchedGeometry: ZoomImageMatchedGeometry?

        init(
            id: UUID = UUID(),
            image: UIImage,
            openingStyle: OpeningStyle,
            isOpening: Bool,
            availableMatchedGeometry: ZoomImageMatchedGeometry?
        ) {
            self.id = id
            self.image = image
            self.openingStyle = openingStyle
            self.isOpening = isOpening
            self.availableMatchedGeometry = availableMatchedGeometry
        }
    }

    struct Dismissal {
        enum Style {
            case fade
            case matched(ZoomImageMatchedGeometry)
            case toss(DismissToss)
        }

        let id: UUID
        let style: Style

        init(id: UUID = UUID(), style: Style) {
            self.id = id
            self.style = style
        }
    }

    enum Lifecycle {
        case idle
        case presented(Session)
        case dismissing(Session, Dismissal)
        
        var session: Session? {
            switch self {
            case .idle:
                nil
            case .presented(let session), .dismissing(let session, _):
                session
            }
        }
        
        var dismissal: Dismissal? {
            switch self {
            case .idle, .presented: nil
            case .dismissing(_, let dismissal): dismissal
            }
        }
        
        var isDismissing: Bool {
            dismissal != nil
        }
    }

    struct Drag {
        var offset: CGSize = .zero
        var predictedEndTranslation: CGSize = .zero
        var velocity: CGSize?
    }

    struct Appearance {
        var backgroundOpacity: Double = .zero
        var imageOpacity: Double = .zero
        var overlayOpacity: Double = .zero
    }

    var lifecycle: Lifecycle
    var drag = Drag()
    var appearance = Appearance()
    var isInteractive = true
    var zoomState: ZoomState = .min
    var isZoomedIn = false
    var isShowingOverlay = true
    var accessibilityScrollRequest: AccessibilityScrollRequest?
    /// Exists before an image is inserted and stays stable until a completed dismissal, so SwiftUI sees one canvas throughout the matched transition.
    private(set) var canvasID = UUID()

    init(
        image: UIImage?,
        openingStyle: Session.OpeningStyle,
        availableMatchedGeometry: ZoomImageMatchedGeometry?
    ) {
        if let image {
            lifecycle = .presented(
                Session(
                    image: image,
                    openingStyle: openingStyle,
                    isOpening: true,
                    availableMatchedGeometry: availableMatchedGeometry
                )
            )
        } else {
            lifecycle = .idle
        }
    }

    var session: Session? {
        lifecycle.session
    }

    var displayedImage: UIImage? {
        session?.image
    }

    var presentationID: UUID? {
        session?.id
    }

    var dismissal: Dismissal? {
        lifecycle.dismissal
    }

    var dismissalID: UUID? {
        dismissal?.id
    }

    var isDismissing: Bool {
        lifecycle.isDismissing
    }

    /// The last source match known while the binding held an image.
    var availableMatchedGeometry: ZoomImageMatchedGeometry? {
        session?.availableMatchedGeometry
    }

    /// Starts or replaces the presentation requested by the binding.
    ///
    /// - Returns: Whether the image was inserted, replaced, resumed from a dismissal, or unchanged.
    mutating func present(
        _ image: UIImage,
        openingStyle: Session.OpeningStyle,
        availableMatchedGeometry: ZoomImageMatchedGeometry?
    ) -> PresentationChange {
        switch lifecycle {
        case .idle:
            lifecycle = .presented(
                Session(
                    image: image,
                    openingStyle: openingStyle,
                    isOpening: true,
                    availableMatchedGeometry: availableMatchedGeometry
                )
            )
            return .inserted

        case .presented(var session):
            guard session.image !== image else {
                session.availableMatchedGeometry = availableMatchedGeometry
                lifecycle = .presented(session)
                return .unchanged
            }

            lifecycle = .presented(
                Session(
                    image: image,
                    openingStyle: openingStyle,
                    isOpening: false,
                    availableMatchedGeometry: availableMatchedGeometry
                )
            )
            resetInteraction()
            return .replaced

        case .dismissing(let session, _):
            let isReplacement = session.image !== image
            lifecycle = .presented(
                Session(
                    image: image,
                    openingStyle: openingStyle,
                    isOpening: true,
                    availableMatchedGeometry: availableMatchedGeometry
                )
            )
            resetInteraction()
            return isReplacement ? .replacedDuringDismissal : .resumed
        }
    }

    /// Ends an opening only when the completion still belongs to the active session.
    @discardableResult
    mutating func finishOpening(id: UUID) -> Bool {
        guard case .presented(var session) = lifecycle,
              session.id == id,
              session.isOpening else {
            return false
        }
        session.isOpening = false
        lifecycle = .presented(session)
        return true
    }

    /// Latches the way the active session will leave.
    @discardableResult
    mutating func beginDismissal(style: Dismissal.Style) -> UUID? {
        guard case .presented(let session) = lifecycle else { return dismissalID }
        let dismissal = Dismissal(style: style)
        lifecycle = .dismissing(session, dismissal)
        return dismissal.id
    }

    /// Gives any image presented during a matched dismissal a fresh canvas identity.
    ///
    /// Called only after SwiftUI has removed the outgoing canvas in the binding transaction, so it cannot disturb that matched pair.
    mutating func prepareCanvasAfterMatchedRemoval() {
        guard case .matched = dismissal?.style else { return }
        canvasID = UUID()
    }

    /// Removes a session only when the completion belongs to its current dismissal.
    @discardableResult
    mutating func finishDismissal(id: UUID) -> Bool {
        guard case .dismissing(_, let dismissal) = lifecycle, dismissal.id == id else {
            return false
        }

        lifecycle = .idle
        canvasID = UUID()
        resetInteraction()
        appearance = Appearance()
        return true
    }

    mutating func resetInteraction() {
        drag = Drag()
        zoomState = .min
        isZoomedIn = false
        isShowingOverlay = true
        accessibilityScrollRequest = nil
        isInteractive = true
    }
}

extension ZoomImagePresentationState {
    enum PresentationChange {
        case unchanged
        case inserted
        case replaced
        case resumed
        case replacedDuringDismissal
    }
}
