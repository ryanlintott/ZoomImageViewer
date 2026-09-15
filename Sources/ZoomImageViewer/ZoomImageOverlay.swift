//
//  ZoomImageOverlay.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// The overlay a ``ZoomImageView`` shows by default: the built-in close button, placed in a corner or along an edge.
///
/// The button is padded from the edges of the viewer and, on iOS 26 and up, offset clear of system UI in the container's corners, like the traffic lights on an iPad window.
///
/// Use it in a custom overlay to keep the default close button while adding other views.
///
/// ```swift
/// ZoomImageView(uiImage: $uiImage) {
///     ZoomImageDefaultOverlay(closeButtonPosition: .topTrailing)
///
///     Text("Two eagles catching a fish")
///         .padding()
///         .frame(maxHeight: .infinity, alignment: .bottom)
/// }
/// ```
public struct ZoomImageDefaultOverlay: View {
    let closeButtonPosition: Alignment
    
    /// Creates the default overlay.
    /// - Parameter closeButtonPosition: The close button position within the entire viewable frame.
    public init(closeButtonPosition: Alignment = .topLeading) {
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
        ZoomImageCloseButton()
            .padding()
            .containerCornerOffsetIfAvailable(cornerOffsetEdges)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: closeButtonPosition)
    }
}

