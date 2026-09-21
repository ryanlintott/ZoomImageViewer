//
//  ZoomImageView.swift
//  ZoomImageView
//
//  Created by Ryan Lintott on 2021-01-13.
//

import SwiftUI

/// A view for displaying fullscreen images that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture.
///
/// Replaced by the ``SwiftUICore/View/zoomImageViewer(uiImage:closeButtonPosition:)`` modifier, which places the viewer over the view it is attached to.
@available(*, deprecated, message: "Use the zoomImageViewer(uiImage:) modifier instead.")
public struct ZoomImageView<Overlay: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var uiImage: UIImage?
    let overlay: Overlay

    internal init(uiImage: Binding<UIImage?>, @ViewBuilder overlay: () -> Overlay) {
        self._uiImage = uiImage
        self.overlay = overlay()
    }

    public var body: some View {
        ZoomImageViewerHost(
            uiImage: $uiImage,
            closeAction: ZoomImageCloseAction(binding: $uiImage),
            overlay: overlay,
            matchedGeometry: nil,
            reduceMotionAtInsertion: reduceMotion
        )
    }
}

@available(*, deprecated)
public extension ZoomImageView<ZoomImageDefaultOverlay> {
    /// Creates a view with a zoomable image and the built-in close button in the top trailing corner.
    /// - Parameters:
    ///   - uiImage: Image to present.
    @available(*, deprecated, message: "Use the zoomImageViewer(uiImage:) modifier instead.")
    init(uiImage: Binding<UIImage?>) {
        self.init(uiImage: uiImage) {
            ZoomImageDefaultOverlay()
        }
    }

    /// Creates a view with a zoomable image and the built-in close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    @available(*, deprecated, message: "Use the zoomImageViewer(uiImage:closeButtonPosition:) modifier instead.")
    init(uiImage: Binding<UIImage?>, closeButtonPosition: Alignment) {
        self.init(uiImage: uiImage) {
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }
}

@available(*, deprecated)
public extension ZoomImageView<AnyView> {
    /// Creates a view with a zoomable image and a close button in the given style.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    @available(*, deprecated, message: "Use the zoomImageViewer(uiImage:overlay:) modifier with a styled default overlay instead: .zoomImageViewer(uiImage: $uiImage) { _ in ZoomImageDefaultOverlay(closeButtonPosition: position).buttonStyle(style) }")
    init<CloseButtonStyle: ButtonStyle>(
        uiImage: Binding<UIImage?>,
        closeButtonStyle: CloseButtonStyle,
        closeButtonPosition: Alignment = .topTrailing
    ) {
        /// Type erased because a style applied with `buttonStyle(_:)` has no type that can be named here.
        self.init(uiImage: uiImage) {
            AnyView(
                ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
                    .buttonStyle(closeButtonStyle)
            )
        }
    }
}
