//
//  ZoomImageViewerContent.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// A zoom image viewer, as passed to the closure given to ``SwiftUICore/View/zoomImageViewerWrapper(_:)`` to place in a wrapper.
public struct ZoomImageViewerContent: View {
    /// Type erased because an environment value cannot retain the arbitrary generic type of every viewer it wraps.
    let viewer: AnyView

    init(_ viewer: some View) {
        self.viewer = AnyView(viewer)
    }

    public var body: some View {
        viewer
    }
}
