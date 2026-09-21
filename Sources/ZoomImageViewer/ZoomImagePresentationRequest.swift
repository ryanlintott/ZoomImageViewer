//
//  ZoomImagePresentationRequest.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// One coherent update of the external values that determine a presentation transition.
///
/// SwiftUI's one-parameter `onChange` closure sees the view from before the change. Carrying the
/// image, its newly resolved source and Reduce Motion setting in the observed value prevents the
/// host from combining a new image with source information captured by the previous render.
struct ZoomImagePresentationRequest: Equatable {
    let image: UIImage?
    let matchedGeometry: ZoomImageMatchedGeometry?
    let reduceMotion: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
            && lhs.matchedGeometry == rhs.matchedGeometry
            && lhs.reduceMotion == rhs.reduceMotion
    }
}
