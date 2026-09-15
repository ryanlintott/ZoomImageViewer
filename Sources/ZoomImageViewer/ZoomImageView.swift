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
///
/// Like in Photos, the image ignores the safe area, filling the whole frame and panning to its edges when zoomed in, while the overlay stays inside the safe area. Zooming the image in hides the overlay, status bar and home indicator, and zooming back out to fit shows them again. A single tap shows or hides the overlay at any zoom, and the status bar and home indicator with it while the image is zoomed out. Panning or zooming a zoomed in image hides the overlay again. The home indicator is only hidden on iOS 16 and up.
///
/// With VoiceOver the viewer is modal and the image is a single element, described by the `UIImage`'s `accessibilityLabel`. The escape gesture closes the viewer. On iOS 16 and up, VoiceOver's zoom action zooms in on the middle of the screen and back out, and three-finger swipes pan a zoomed in image half a screen at a time. The image's Show Controls and Hide Controls actions do the same as a single tap.
public struct ZoomImageView<Overlay: View>: View {
    @Binding private var uiImage: UIImage?
    let overlay: Overlay
    
    /// Creates a view with a zoomable image and a custom overlay.
    ///
    /// The overlay covers the viewer's frame inside its safe area, fades in and out with the image, and is hidden while the image is zoomed in or after a single tap. Buttons in it use ``ZoomImageDefaultButtonStyle`` unless they set their own style. Placing and padding the views is up to you. Use ``ZoomImageDefaultOverlay`` to keep the default close button.
    ///
    /// The overlay is the only way to close the viewer other than dragging the image away, so include a close button. ``ZoomImageCloseButton`` closes the viewer it is in, and your own buttons can do the same with the ``SwiftUICore/EnvironmentValues/closeZoomImage`` action.
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
    /// - Parameters:
    ///   - uiImage: Image to present. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer, fading it out.
    ///   - overlay: The views shown over the image, stacked on top of each other.
    public init(
        uiImage: Binding<UIImage?>,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self._uiImage = uiImage
        /// Built here, while the view creating this one updates, so any state the overlay reads is tracked by that view and the overlay is rebuilt when it changes.
        self.overlay = overlay()
    }
    
    public var body: some View {
        /// Always in the hierarchy, so a viewer can fade out after its binding is cleared rather than being removed with it.
        _ZoomImageView(uiImage: $uiImage, overlay: overlay)
    }
}

public extension ZoomImageView<ZoomImageDefaultOverlay> {
    /// Creates a view with a zoomable image and the built-in close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    init(uiImage: Binding<UIImage?>, closeButtonPosition: Alignment = .topLeading) {
        self.init(uiImage: uiImage) {
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }
}

public extension ZoomImageView<AnyView> {
    /// Creates a view with a zoomable image and a close button in the given style.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    @available(*, deprecated, message: "Style the default overlay instead: ZoomImageView(uiImage:) { ZoomImageDefaultOverlay(closeButtonPosition: position).buttonStyle(style) }")
    init<CloseButtonStyle: ButtonStyle>(
        uiImage: Binding<UIImage?>,
        closeButtonStyle: CloseButtonStyle,
        closeButtonPosition: Alignment = .topLeading
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
