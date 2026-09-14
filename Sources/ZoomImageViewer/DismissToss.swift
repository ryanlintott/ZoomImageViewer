//
//  DismissToss.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// How an image dragged far enough to dismiss leaves the screen, carrying on from the drag that threw it.
///
/// The image moves away from where it was let go in the direction it was moving, starting at exactly the speed of the drag so there is no pause or jump as the finger lifts. It always travels at least a minimum distance, speeding up when the throw alone would not carry it that far in time. A spring could not do this: its initial velocity is a fraction of the distance it animates across, and one aimed far enough to clear the screen has to speed up after it starts, which feels like a delay before the image shoots away.
struct DismissToss: Equatable {
    /// Where the image ends up.
    let endOffset: CGSize
    /// The speed the image starts at as a fraction of its speed at the end, between 0 and 1.
    let startSpeedFraction: CGFloat
    let duration: TimeInterval
    
    /// - Parameters:
    ///   - offset: Where the image is when the drag ends.
    ///   - velocity: The drag's velocity in points per second, when it is known.
    ///   - predictedEndTranslation: Where the drag was heading, used for the direction when the velocity does not lead away from the image's resting place.
    ///   - minimumDistance: How far the image travels from where it was let go however slowly it was thrown, which should be far enough to be sure it leaves the screen.
    ///   - duration: How long the image takes to leave.
    init(offset: CGSize, velocity: CGSize?, predictedEndTranslation: CGSize, minimumDistance: CGFloat, duration: TimeInterval) {
        let velocity = velocity ?? .zero
        /// The velocity is followed when it carries the image the way the drag was heading. Otherwise, such as when the image is let go while drifting back, it leaves the way it was dragged instead of flying back across the screen.
        let isHeadingAway = velocity.width * predictedEndTranslation.width + velocity.height * predictedEndTranslation.height > 0
        let direction = isHeadingAway ? velocity.normalized : predictedEndTranslation.normalized
        let releaseSpeed = Swift.max(0, velocity.width * direction.width + velocity.height * direction.height)
        
        let distance = Swift.max(releaseSpeed * duration, minimumDistance)
        
        endOffset = offset + direction * distance
        /// The toss's speed at the end is its distance over its duration, so the release speed as a fraction of that is where the curve has to start.
        startSpeedFraction = distance > 0 ? releaseSpeed * duration / distance : 1
        self.duration = duration
    }
    
    /// A timing curve that starts at the release speed and ends at the toss's full speed.
    ///
    /// Both horizontal control points sit a third of the way along, so time passes evenly through the curve and its slope is the speed directly. The first control point sets the starting slope to ``startSpeedFraction`` and the second sits on the diagonal, ending at the full speed. A throw fast enough to cover the minimum distance on its own has a fraction of 1, which is a straight line: the image carries on at exactly the speed it was thrown.
    var animation: Animation {
        .timingCurve(1 / 3, startSpeedFraction / 3, 2 / 3, 2 / 3, duration: duration)
    }
}
