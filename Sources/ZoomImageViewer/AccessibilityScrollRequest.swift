//
//  AccessibilityScrollRequest.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import UIKit

/// A request from an assistive technology to scroll the image towards one of its edges.
///
/// Each request is a new value, so the scroll view can tell a repeated scroll towards the same edge apart from an update that carries an old request.
struct AccessibilityScrollRequest: Equatable {
    /// The edge of the image to scroll towards.
    let edge: UIRectEdge
    let id = UUID()
}
