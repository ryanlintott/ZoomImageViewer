//
//  ZoomImageMatchedGeometry.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI

/// The matched geometry effect a viewer's image grows from when it opens and shrinks back to when it closes.
struct ZoomImageMatchedGeometry: Equatable {
    /// The identifier shared with the source view.
    ///
    /// Kept as its own type rather than an `AnyHashable`, as SwiftUI only matches identifiers of the same type. An `AnyHashable` never matches the `Int` or `UUID` a source view was given, even when their values are equal.
    let id: any Hashable
    let namespace: Namespace.ID
    
    /// Compares identifiers type erased, which is only for telling when they change. SwiftUI still matches a source by the identifier's own type.
    static func == (lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.id) == AnyHashable(rhs.id) && lhs.namespace == rhs.namespace
    }
    
    /// The spring the image lands on its source with.
    ///
    /// Just short of bouncing, so a throw follows through and settles rather than wobbling. A spring has no moment it is finished, but it spends the end of its travel so close to its source that the two can be swapped without it being seen.
    static let spring = (mass: 1.0, stiffness: 200.0, damping: 27.0)
    
    /// How long the image takes to settle on its source before the source fades back in under it.
    ///
    /// By this point the spring is within a point of its source and barely moving, so the two line up. The image is still left in place, on top of its source, until the viewer is taken away around it.
    static let landingDelay = 0.5
    
    /// How long the image and its source take to swap.
    static let swapDuration = 0.1
    
    /// How long a landing is given before the viewer is taken away around it, which is when the image is finally removed.
    ///
    /// Long enough for the spring to have settled, so the image is sitting exactly on its source as it goes. Nothing else of the viewer can be seen by then, as it has finished fading out.
    static let settlingDuration = 0.7
    
    /// The highest speed the image is allowed to set off at, as a fraction of the distance it has to cover per second.
    ///
    /// A flick that lets go of the image almost as soon as it starts moving it is fast over a very short distance, which without a limit would carry the image far past its source before drawing it back.
    static let maximumStartSpeed: CGFloat = 4
    
    /// How the image lands on its source, setting off at `startSpeed`.
    ///
    /// An interpolating spring, which is the only animation that carries a speed into it, so an image let go of by a drag keeps travelling the way it was thrown instead of turning on the spot. It also picks up from wherever the image is if the viewer is opened again part way through.
    /// - Parameter startSpeed: How fast the image is already moving towards where it lands, as a fraction of the distance it has to cover per second. A negative speed carries it further away first, which is how a drag thrown away from the source follows through before the image is drawn back to it.
    static func landingAnimation(startSpeed: CGFloat = 0) -> Animation {
        .interpolatingSpring(mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping, initialVelocity: startSpeed)
    }
    
    /// How fast an image let go of by a drag is already moving, as a fraction of the distance it covers as it lands per second.
    ///
    /// Measured across and down separately, as spring timing parameters take a vector rather than a single speed. A drag is rarely heading straight at the source, and a single speed along the way the image lands would keep only the part of the throw in that direction and drop the rest, turning the image on the spot as it sets off. Each axis carrying its own speed leaves the image travelling exactly the way it was thrown.
    ///
    /// An axis heading away from where the image lands, which is most of a throw away from the source, gives a negative speed that follows it out before the image is drawn back.
    /// - Parameters:
    ///   - move: How far the image moves as it lands, from where it is now to where it ends up.
    ///   - velocity: The drag's velocity in points per second, when it is known.
    static func landingStartSpeed(move: CGSize, velocity: CGSize?) -> CGSize {
        guard let velocity else { return .zero }
        
        /// A spring's speed is measured in the distance it travels per second, so each axis is divided by how far it has to go.
        let speed = CGSize(
            width: move.width == 0 ? 0 : velocity.width / move.width,
            height: move.height == 0 ? 0 : velocity.height / move.height
        )
        
        /// An axis with almost no distance to cover is a large fraction of it however gently the image was thrown, so both axes are brought down together rather than one being cut short, leaving the image still travelling the way it was thrown.
        let fastest = Swift.max(abs(speed.width), abs(speed.height))
        guard fastest > maximumStartSpeed else { return speed }
        return (maximumStartSpeed / fastest) * speed
    }
    
    /// Adds and removes the image, moving and turning it on its way to and from its source.
    ///
    /// The move carries an image dragged away from the middle of the frame on to where it lands, as matched geometry only moves the image between the frames of the two views and knows nothing of an offset applied to either. Each axis is moved on its own so it can set off at the speed the drag was travelling on that axis, which is what carries a throw smoothly into the landing. It is the only part that follows the drag, as a throw moves the image around rather than changing its size, so the frame it is moving between, and the turn, carry on evenly.
    ///
    /// The turn undoes the one a container like `AutoRotatingView` applies to the whole viewer, so the image ends up square with its source rather than sideways and away from it.
    ///
    /// Both are applied to a view filling the viewer's frame rather than to the image, so they move and turn around the same point whatever size the image is at. The image itself never fades, so it is always fully there as it lands, and is left sitting on top of its source until the viewer is taken away around it.
    /// - Parameters:
    ///   - rotation: How far the viewer is turned from the window its source is in.
    ///   - move: How far the image moves as it lands, from where it is now to where it ends up.
    ///   - startSpeed: How fast the image is already moving on each axis when a drag lets go of it.
    static func imageTransition(undoing rotation: ZoomImageContentRotation, moving move: CGSize, startSpeed: CGSize) -> AnyTransition {
        let turning = AnyTransition.modifier(
            active: ZoomImageTurnModifier(progress: 1, rotation: rotation),
            identity: ZoomImageTurnModifier(progress: .zero, rotation: rotation)
        )

        return movingTransition(distance: move.width, startSpeed: startSpeed.width, axis: .horizontal)
            .combined(with: movingTransition(distance: move.height, startSpeed: startSpeed.height, axis: .vertical))
            .combined(with: turning)
    }
    
    /// Moves the image `distance` along `axis` as it lands, setting off at `startSpeed`.
    private static func movingTransition(distance: CGFloat, startSpeed: CGFloat, axis: Axis) -> AnyTransition {
        .modifier(
            active: ZoomImageMoveModifier(progress: 1, distance: distance, axis: axis),
            identity: ZoomImageMoveModifier(progress: .zero, distance: distance, axis: axis)
        )
        .animation(landingAnimation(startSpeed: startSpeed))
    }
}

extension View {
    /// Matches the geometry of views with the same identifier in `matchedGeometry`'s namespace, or leaves the view alone when there is none.
    @ViewBuilder
    func matchedGeometryEffect(_ matchedGeometry: ZoomImageMatchedGeometry?) -> some View {
        if let matchedGeometry {
            matchedGeometryEffect(opening: matchedGeometry.id, in: matchedGeometry.namespace)
        } else {
            self
        }
    }

    /// Applies a matched geometry effect with the identifier's own type, opened from the existential it was stored as.
    ///
    /// Type erased, as the type of the modified view depends on the identifier's type, which is only known at runtime. Every identifier a viewer is given is usually the same type, so the erased view keeps its identity from one update to the next.
    private func matchedGeometryEffect<ID: Hashable>(opening id: ID, in namespace: Namespace.ID) -> AnyView {
        AnyView(matchedGeometryEffect(id: id, in: namespace))
    }
}

/// Moves an image along one axis on its way to where it lands.
///
/// Used by a transition rather than applied to the view, as SwiftUI leaves a view being removed as it was and animates only the transition it is given. An offset set on the view itself, or on anything around it, is applied to a removed image at once instead, dragging it back to the middle of the frame before it sets off.
///
/// One axis at a time, so each can set off at the speed the drag was travelling on it and the image leaves along the way it was thrown rather than turning on the spot.
struct ZoomImageMoveModifier: ViewModifier, Animatable {
    /// How far the image is through its landing on this axis, from 0 where it is now to 1 where it ends up.
    var progress: Double

    /// How far the image moves along `axis` as it lands, on top of the frame its matched geometry takes it to.
    var distance: CGFloat

    var axis: Axis

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        switch axis {
        case .horizontal: content.offset(x: distance * progress)
        case .vertical: content.offset(y: distance * progress)
        }
    }
}
