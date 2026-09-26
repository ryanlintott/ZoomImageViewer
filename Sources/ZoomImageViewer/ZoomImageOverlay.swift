//
//  ZoomImageOverlay.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// The overlay a zoom image viewer shows by default: the built-in close button, placed in a corner or along an edge.
///
/// Unless given a position, the button goes where a system close button on a fullscreen sheet would. On iOS 27.1 and up it avoids the system UI the container reserves, like the status bar and camera on iPhone Duo: at the top of a vertical bar on whichever side it is, beside system UI in a top corner, and otherwise in the top trailing corner, concentric with it. The regions follow a wrapper that turns the viewer, like `AutoRotatingView` from FrameUp.
///
/// Before iOS 27.1 the button is padded from the safe area in the top trailing corner and, on iOS 26, offset clear of system UI in the container's corners, like the traffic lights on an iPad window.
///
/// Use it in a custom overlay to keep the default close button while adding other views.
///
/// ```swift
/// .zoomImageViewer(uiImage: $uiImage) { _ in
///     ZoomImageDefaultOverlay()
///
///     Text("Two eagles catching a fish")
///         .padding()
///         .frame(maxHeight: .infinity, alignment: .bottom)
/// }
/// ```
public struct ZoomImageDefaultOverlay: View {
    let closeButtonPosition: Alignment?
    
    /// Creates the default overlay.
    /// - Parameter closeButtonPosition: The close button position within the entire viewable frame, or `nil` for where a system close button would go. Defaults to `nil`.
    public init(closeButtonPosition: Alignment? = nil) {
        self.closeButtonPosition = closeButtonPosition
    }
    
    public var body: some View {
        /// `reservedRegions` first appears in the iOS 27.1 SDK. Xcode 27.0 has the same compiler, so the SDK is checked by its SwiftUICore version, which is 8.0.84 in 27.0 and 8.0.85 in 27.1.
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            ZoomImageRegionAwareCloseButton(position: closeButtonPosition)
        } else {
            legacyBody
        }
        #else
        legacyBody
        #endif
    }
    
    /// The button padded from the safe area, before reserved regions can be read.
    var legacyBody: some View {
        let position = closeButtonPosition ?? .topTrailing
        return ZoomImageCloseButton()
            .padding(ZoomImageCloseButtonPlacement.padding)
            .containerCornerOffsetIfAvailable(Self.cornerOffsetEdges(position))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position)
    }
    
    /// The edge beside the corner the close button is in, which is the one the container's corner can overlap.
    static func cornerOffsetEdges(_ position: Alignment) -> Edge.Set {
        switch position {
        case .topLeading, .bottomLeading: .leading
        case .topTrailing, .bottomTrailing: .trailing
        default: []
        }
    }
}

#if canImport(SwiftUICore, _version: 8.0.85)
/// The built-in close button, placed in the whole frame of the viewer clear of the system UI the container reserves.
///
/// SwiftUI maps reserved regions through a rotation, so this follows a wrapper that turns the viewer.
@available(iOS 27.1, *)
struct ZoomImageRegionAwareCloseButton: View {
    /// The close button position, or `nil` for where a system close button would go.
    let position: Alignment?
    
    var body: some View {
        GeometryReader { safeAreaProxy in
            /// Read outside the next reader, which ignores the safe area and so reports none.
            let safeAreaInsets = safeAreaProxy.safeAreaInsets
            GeometryReader { proxy in
                let placement = ZoomImageCloseButtonPlacement(
                    position: position,
                    size: proxy.size,
                    safeAreaInsets: safeAreaInsets,
                    occlusionFrames: proxy.reservedRegions(kind: .occlusion).map(\.frame)
                )
                ZoomImageCloseButton()
                    .fixedSize()
                    .frame(width: placement.slotWidth, height: placement.slotHeight)
                    .padding(placement.padding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placement.alignment)
            }
            .ignoresSafeArea()
        }
    }
}
#endif
