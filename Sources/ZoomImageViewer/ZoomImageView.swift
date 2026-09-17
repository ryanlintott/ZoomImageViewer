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
    /// The namespace the image's source is in, or `nil` for a viewer that fades its image in and out.
    let namespace: Namespace.ID?
    /// The identifier of the source of the image in the binding, or `nil` when there is no image or no source.
    let sourceID: (any Hashable)?
    
    /// Creates a view with a zoomable image and a custom overlay.
    ///
    /// The overlay covers the viewer's frame inside its safe area, fades in and out with the image, and is hidden while the image is zoomed in or after a single tap. Buttons in it use ``ZoomImageDefaultButtonStyle`` unless they set their own style. Placing and padding the views is up to you. Use ``ZoomImageDefaultOverlay`` to keep the default close button.
    ///
    /// The overlay is the only way to close the viewer other than dragging the image away, so include a close button. ``ZoomImageCloseButton`` closes the viewer it is in, and your own buttons can do the same with the ``SwiftUICore/EnvironmentValues/closeZoomImage`` action.
    ///
    /// ```swift
    /// ZoomImageView(uiImage: $uiImage) {
    ///     ZoomImageDefaultOverlay()
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
        self.init(uiImage: uiImage, namespace: nil, sourceID: nil, overlay: overlay)
    }
    
    /// Creates a view with a zoomable image that grows from its item's source view, like a thumbnail, and a custom overlay that receives the item.
    ///
    /// Give each source view the ``SwiftUICore/View/zoomImageSource(for:selection:in:)`` modifier with its item, the same item binding's value as the selection, and the same namespace. The item's `id` matches the image to its source, so the image grows from the source of the item that was set and shrinks back into the source of the item on screen when the viewer closes, including after stepping to another item. The viewer animates this itself, so set the item without `withAnimation`. It animates its own closes too, from the close button, the escape gesture or dragging the image away, and a dragged image shrinks back to its source rather than being thrown off screen.
    ///
    /// Only the image is matched. The background and overlay fade in and out as usual. A viewer inside a container that turns its content, like `AutoRotatingView` from FrameUp, turns the image back as it lands on its source, so it arrives square with it. The image is fitted to the frame it grows from, so a source that shows the whole image, like one with `scaledToFit()`, matches it most closely.
    ///
    /// ```swift
    /// @Namespace private var namespace
    /// @State private var selectedPhoto: Photo? = nil
    ///
    /// var body: some View {
    ///     VStack {
    ///         ForEach(photos) { photo in
    ///             Button {
    ///                 selectedPhoto = photo
    ///             } label: {
    ///                 Image(uiImage: photo.image)
    ///                     .resizable()
    ///                     .scaledToFit()
    ///                     .zoomImageSource(for: photo, selection: selectedPhoto, in: namespace)
    ///             }
    ///         }
    ///     }
    ///     .overlay(
    ///         ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace) { photo in
    ///             ZoomImageDefaultOverlay()
    ///
    ///             Text(photo.caption)
    ///                 .padding()
    ///                 .frame(maxHeight: .infinity, alignment: .bottom)
    ///         }
    ///     )
    /// }
    /// ```
    ///
    /// Setting or clearing the item always grows or shrinks the image with the viewer's own spring. An animation the item is changed with, like one from `withAnimation`, is ignored for this, and there is no way to show or hide the image without animating.
    ///
    /// The overlay is built for the item on screen, and keeps showing the last item while the viewer fades out after the item is cleared.
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer. `Equatable`, so the overlay can tell when the item changes and fade out with its latest contents.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does, as a different instance is shown as a replacement image.
    ///   - namespace: The namespace the source views are in.
    ///   - overlay: The views shown over the image for an item, stacked on top of each other.
    public init<Item: Identifiable & Equatable, Content: View>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        in namespace: Namespace.ID,
        @ViewBuilder overlay: @escaping (Item) -> Content
    ) where Overlay == ZoomImageItemOverlay<Item, Content> {
        self.init(uiImage: item.zoomImage(image), namespace: namespace, sourceID: item.wrappedValue?.id) {
            /// Reads the item while the view creating this one updates, so that view is updated whenever the item changes and the overlay is built for the new one.
            ZoomImageItemOverlay(item: item.wrappedValue, content: overlay)
        }
    }
    
    init(
        uiImage: Binding<UIImage?>,
        namespace: Namespace.ID?,
        sourceID: (any Hashable)?,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self._uiImage = uiImage
        self.namespace = namespace
        self.sourceID = sourceID
        /// Built here, while the view creating this one updates, so any state the overlay reads is tracked by that view and the overlay is rebuilt when it changes.
        self.overlay = overlay()
    }
    
    /// The matched geometry effect for the image in the binding, or `nil` when there is no image or no source.
    var matchedGeometry: ZoomImageMatchedGeometry? {
        guard let namespace, let sourceID else { return nil }
        return ZoomImageMatchedGeometry(id: sourceID, namespace: namespace)
    }
    
    public var body: some View {
        /// Always in the hierarchy, so a viewer can fade out after its binding is cleared rather than being removed with it.
        if namespace != nil {
            /// Grows and shrinks the image with the landing spring whatever animation the binding was changed with, matching the one its source's stand-in is inserted and removed with. Only for viewers with a namespace, which comes from the initializer and never changes, so the branch taken stays the same for the life of the viewer. A viewer without it keeps the caller's transaction.
            _ZoomImageView(uiImage: $uiImage, overlay: overlay, matchedGeometry: matchedGeometry)
                .animation(ZoomImageMatchedGeometry.landingAnimation(), value: uiImage != nil)
        } else {
            _ZoomImageView(uiImage: $uiImage, overlay: overlay, matchedGeometry: matchedGeometry)
        }
    }
}

public extension ZoomImageView<ZoomImageDefaultOverlay> {
    /// Creates a view with a zoomable image and the built-in close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    init(uiImage: Binding<UIImage?>, closeButtonPosition: Alignment = .topTrailing) {
        self.init(uiImage: uiImage) {
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }
    
    /// Creates a view with a zoomable image that grows from its item's source view, like a thumbnail, and the built-in close button.
    ///
    /// See ``init(item:image:in:overlay:)`` for how to set up the source views.
    ///
    /// ```swift
    /// ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace)
    /// ```
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does.
    ///   - namespace: The namespace the source views are in.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    init<Item: Identifiable & Equatable>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        in namespace: Namespace.ID,
        closeButtonPosition: Alignment = .topTrailing
    ) {
        self.init(uiImage: item.zoomImage(image), namespace: namespace, sourceID: item.wrappedValue?.id) {
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }
}

public extension ZoomImageView<AnyView> {
    /// Creates a view with a zoomable image and a close button in the given style.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    @available(*, deprecated, message: "Style the default overlay instead: ZoomImageView(uiImage:) { ZoomImageDefaultOverlay(closeButtonPosition: position).buttonStyle(style) }")
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
