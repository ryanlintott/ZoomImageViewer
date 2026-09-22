//
//  ZoomImagePresentationTransition.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-21.
//

import SwiftUI

/// How an image enters or leaves the viewer.
///
/// A transition retains the geometry or toss it started with, so a source moving or Reduce Motion
/// changing cannot alter an animation already in progress.
enum ZoomImagePresentationTransition: Equatable {
    case fade
    case matched(ZoomImageMatchedGeometry)
    case toss(DismissToss)

    /// The transition for an image being presented from the current source.
    static func opening(
        matchedGeometry: ZoomImageMatchedGeometry?,
        reduceMotion: Bool
    ) -> Self {
        guard let matchedGeometry, !reduceMotion else { return .fade }
        return .matched(matchedGeometry)
    }

    /// The matched geometry retained by this transition, or `nil` when the image fades or is tossed.
    var matchedGeometry: ZoomImageMatchedGeometry? {
        guard case .matched(let matchedGeometry) = self else { return nil }
        return matchedGeometry
    }

    /// Whether the fullscreen image stays in the hierarchy until dismissal cleanup.
    ///
    /// A matched image is removed with the binding so its source can return in the same transaction.
    /// A fading or tossed image has no source to replace it and remains until its transition finishes.
    var keepsImageDuringDismissal: Bool {
        matchedGeometry == nil
    }

    /// How long the transition is given to finish before its retained presentation is removed.
    /// - Parameter fadeDuration: The viewer's configured fade duration.
    func settlingDuration(fadeDuration: TimeInterval) -> TimeInterval {
        switch self {
        case .fade:
            fadeDuration
        case .matched:
            ZoomImageMatchedGeometry.settlingDuration
        case .toss(let toss):
            toss.duration
        }
    }

    /// The SwiftUI transition that inserts or removes the fullscreen image.
    ///
    /// Matched geometry handles the image's frame. This transition separately carries a dragged
    /// image back from its offset and undoes any rotation applied around the viewer. Images without
    /// matched geometry use opacity; a toss moves with its explicit offset animation before removal.
    func imageTransition(
        undoing rotation: ContentRotation,
        moving move: CGSize,
        velocity: CGSize?
    ) -> AnyTransition {
        guard matchedGeometry != nil else { return .opacity }

        return ZoomImageMatchedGeometry.imageTransition(
            undoing: rotation,
            moving: move,
            startSpeed: ZoomImageMatchedGeometry.landingStartSpeed(
                move: move,
                velocity: velocity
            )
        )
    }
}
