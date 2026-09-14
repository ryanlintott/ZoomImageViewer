//
//  ZoomImageView.swift
//  ZoomImageView
//
//  Created by Ryan Lintott on 2021-01-13.
//

import SwiftUI

/// A view for displaying fullscreen images that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture.
///
/// The close button is part of an overlay that can be restyled, or replaced with any views, like other controls or captions.
public struct ZoomImageView<Overlay: View>: View {
    @Binding private var uiImage: UIImage?
    let overlay: (ZoomImageOverlayContext) -> Overlay
    
    /// Creates a view with a zoomable image and a custom overlay.
    ///
    /// The overlay covers the viewer's frame inside its safe area, and fades in and out with the image. Buttons in it use ``ZoomImageDefaultButtonStyle`` unless they set their own style. Placing and padding the views is up to you. Use ``ZoomImageDefaultOverlay`` to keep the default close button.
    ///
    /// The overlay is the only way to close the viewer other than dragging the image away, so include a button that calls the context's `close` action.
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
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - overlay: Builds the views shown over the image. Views are stacked on top of each other.
    public init(
        uiImage: Binding<UIImage?>,
        @ViewBuilder overlay: @escaping (_ viewer: ZoomImageOverlayContext) -> Overlay
    ) {
        self._uiImage = uiImage
        self.overlay = overlay
    }
    
    public var body: some View {
        if uiImage != nil {
            _ZoomImageView(uiImage: $uiImage, overlay: overlay)
        }
    }
}

public extension ZoomImageView<ZoomImageDefaultOverlay> {
    /// Creates a view with a zoomable image and the built-in close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    init(uiImage: Binding<UIImage?>, closeButtonPosition: Alignment = .topLeading) {
        self.init(uiImage: uiImage) { viewer in
            ZoomImageDefaultOverlay(viewer, closeButtonPosition: closeButtonPosition)
        }
    }
}

public extension ZoomImageView<AnyView> {
    /// Creates a view with a zoomable image and a close button in the given style.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    @available(*, deprecated, message: "Style the default overlay instead: ZoomImageView(uiImage:) { viewer in ZoomImageDefaultOverlay(viewer, closeButtonPosition: position).buttonStyle(style) }")
    init<CloseButtonStyle: ButtonStyle>(
        uiImage: Binding<UIImage?>,
        closeButtonStyle: CloseButtonStyle,
        closeButtonPosition: Alignment = .topLeading
    ) {
        /// Type erased because a style applied with `buttonStyle(_:)` has no type that can be named here.
        self.init(uiImage: uiImage) { viewer in
            AnyView(
                ZoomImageDefaultOverlay(viewer, closeButtonPosition: closeButtonPosition)
                    .buttonStyle(closeButtonStyle)
            )
        }
    }
}
