//
//  ZoomImageOverlay.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// What a ``ZoomImageView`` gives the views in its overlay.
public struct ZoomImageOverlayContext {
    /// Dismisses the image.
    public let close: @MainActor () -> Void
    
    init(close: @escaping @MainActor () -> Void) {
        self.close = close
    }
}

/// The overlay a ``ZoomImageView`` shows by default: the built-in close button, placed in a corner or along an edge.
///
/// The button is padded from the edges of the viewer and, on iOS 26 and up, offset clear of system UI in the container's corners, like the traffic lights on an iPad window.
///
/// Use it in a custom overlay to keep the default close button while adding other views.
///
/// ```swift
/// ZoomImageView(uiImage: $uiImage) { viewer in
///     ZoomImageDefaultOverlay(viewer, closeButtonPosition: .topTrailing)
///
///     Text("Two eagles catching a fish")
///         .padding()
///         .frame(maxHeight: .infinity, alignment: .bottom)
/// }
/// ```
public struct ZoomImageDefaultOverlay: View {
    let viewer: ZoomImageOverlayContext
    let closeButtonPosition: Alignment
    
    /// Creates the default overlay.
    /// - Parameters:
    ///   - viewer: The context the ``ZoomImageView`` passes to its overlay.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    public init(_ viewer: ZoomImageOverlayContext, closeButtonPosition: Alignment = .topLeading) {
        self.viewer = viewer
        self.closeButtonPosition = closeButtonPosition
    }
    
    /// The edge beside the corner the close button is in, which is the one the container's corner can overlap.
    var cornerOffsetEdges: Edge.Set {
        switch closeButtonPosition {
        case .topLeading, .bottomLeading: .leading
        case .topTrailing, .bottomTrailing: .trailing
        default: []
        }
    }
    
    public var body: some View {
        ZoomImageCloseButton(action: viewer.close)
            .padding()
            .containerCornerOffsetIfAvailable(cornerOffsetEdges)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: closeButtonPosition)
    }
}

