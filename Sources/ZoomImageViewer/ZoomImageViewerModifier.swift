//
//  ZoomImageViewerModifier.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

public extension View {
    /// Presents an item's image in a fullscreen viewer over this view that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture, growing the image from the item's source view and shrinking it back when it closes.
    ///
    /// The viewer covers this view, so attach it to a view that fills the screen. The image ignores the safe area, filling the whole frame and panning to its edges when zoomed in, like in Photos, while the overlay stays inside the safe area.
    ///
    /// Give each source view inside this view, usually a thumbnail, the ``SwiftUICore/View/zoomImageSource(for:)`` modifier with its item. The item's `id` matches the image to its source, so the image grows from the source of the item that was set and shrinks back into the source of the item on screen when the viewer closes, including after stepping to another item. An item with no source on screen, like one scrolled out of a lazy grid, fades in and out instead. The viewer animates this itself, so set the item without `withAnimation`. It animates its own closes too, from the close button, the escape gesture or dragging the image away, and a dragged image shrinks back to its source rather than being thrown off screen.
    ///
    /// Only the image takes part in the transition. The background and overlay fade in and out as usual. A viewer inside a container that turns its content, like `AutoRotatingView` from FrameUp added with ``SwiftUICore/View/zoomImageViewerWrapper(_:)``, turns the image back as it lands on its source, so it arrives square with it.
    ///
    /// ```swift
    /// @State private var selectedPhoto: Photo? = nil
    ///
    /// var body: some View {
    ///     LazyVGrid(columns: columns) {
    ///         ForEach(photos) { photo in
    ///             Button {
    ///                 selectedPhoto = photo
    ///             } label: {
    ///                 Image(uiImage: photo.image)
    ///                     .resizable()
    ///                     .scaledToFit()
    ///                     .zoomImageSource(for: photo)
    ///             }
    ///         }
    ///     }
    ///     .zoomImageViewer(item: $selectedPhoto, image: \.image) { photo in
    ///         ZoomImageDefaultOverlay()
    ///
    ///         Text(photo.caption)
    ///             .padding()
    ///             .frame(maxHeight: .infinity, alignment: .bottom)
    ///     }
    /// }
    /// ```
    ///
    /// A source belongs to the nearest viewer above it presenting the same type of item, so a second viewer of the same type attached further out fades its images in and out.
    ///
    /// The overlay covers the viewer's frame inside its safe area, fades in and out with the image, and is hidden while the image is zoomed in or after a single tap. It is built for the item on screen, and keeps showing the last item while the viewer fades out after the item is cleared. Buttons in it use ``ZoomImageDefaultButtonStyle`` unless they set their own style. Placing and padding the views is up to you. Use ``ZoomImageDefaultOverlay`` to keep the default close button.
    ///
    /// The overlay is the only way to dismiss the viewer other than dragging the image away, so include a close button. ``ZoomImageCloseButton`` dismisses the viewer it is in, and your own buttons can do the same with the ``SwiftUICore/EnvironmentValues/dismissZoomImage`` action.
    ///
    /// Zooming the image in hides the overlay, status bar and home indicator, and zooming back out to fit shows them again. A single tap shows or hides the overlay at any zoom, and the status bar and home indicator with it while the image is zoomed out. Panning or zooming a zoomed in image hides the overlay again. Dragging the image away hides the overlay, which comes back if the image is put back. The home indicator is only hidden on iOS 16 and up.
    ///
    /// The background is black in both light and dark mode, like in Photos, and the viewer forces the dark colour scheme on everything inside it, so the semantic colours in the overlay are the ones for a dark background whatever the app's appearance.
    ///
    /// With VoiceOver the viewer is modal and the image is a single element, described by the `UIImage`'s `accessibilityLabel`. The escape gesture closes the viewer. On iOS 16 and up, VoiceOver's zoom action zooms in on the middle of the screen and back out, and three-finger swipes pan a zoomed in image half a screen at a time. The image's Show Controls and Hide Controls actions do the same as a single tap.
    ///
    /// Setting or clearing the item always grows or shrinks the image with the viewer's own spring. An animation the item is changed with, like one from `withAnimation`, is ignored for this, and there is no way to show or hide the image without animating.
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer. `Equatable`, so the overlay can tell when the item changes and fade out with its latest contents.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does, as a different instance is shown as a replacement image.
    ///   - overlay: The views shown over the image for an item, stacked on top of each other.
    func zoomImageViewer<Item: Identifiable & Equatable, Content: View>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        @ViewBuilder overlay: @escaping (Item) -> Content
    ) -> some View {
        modifier(
            ZoomImageViewerModifier(
                uiImage: item.zoomImage(image),
                dismissAction: ZoomImageDismissAction(binding: item),
                /// Built here, while the view this modifies updates, so that view is updated whenever the item changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: item.wrappedValue, content: overlay),
                sourceConfiguration: ZoomImageSourceConfiguration(itemType: ObjectIdentifier(Item.self), presentedID: item.wrappedValue?.id)
            )
        )
    }

    /// Presents an item's image in a fullscreen viewer over this view with the built-in close button, growing the image from the item's source view and shrinking it back when it closes.
    ///
    /// See ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)`` for how the viewer works and how to set up the source views. Use that one with ``ZoomImageDefaultOverlay`` to add other views alongside the close button.
    ///
    /// ```swift
    /// .zoomImageViewer(item: $selectedPhoto, image: \.image)
    /// ```
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does, as a different instance is shown as a replacement image.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    func zoomImageViewer<Item: Identifiable & Equatable>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        closeButtonPosition: Alignment = .topTrailing
    ) -> some View {
        zoomImageViewer(item: item, image: image) { _ in
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }

    /// Presents an image in a fullscreen viewer over this view, fading the image in and out, with a custom overlay that receives the image.
    ///
    /// An image has nothing to match a source view by, so it always fades in and out. Present an `Identifiable` item with ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)`` to grow the image from a source view instead, or when the overlay needs more than the image, like a caption.
    ///
    /// ```swift
    /// .zoomImageViewer(uiImage: $uiImage) { uiImage in
    ///     ZoomImageDefaultOverlay()
    ///
    ///     Text(uiImage.accessibilityLabel ?? "")
    ///         .padding()
    ///         .frame(maxHeight: .infinity, alignment: .bottom)
    /// }
    /// ```
    ///
    /// Otherwise the viewer is the same as ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)``, which describes the overlay and how the viewer works. The overlay receives the image on screen, and keeps showing the last one while the viewer fades out, so an overlay describing it doesn't blank out as it closes.
    /// - Parameters:
    ///   - uiImage: The image to present. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer, fading it out. Setting another image while the viewer is open replaces the one on screen.
    ///   - overlay: The views shown over the image, stacked on top of each other.
    func zoomImageViewer<Content: View>(
        uiImage: Binding<UIImage?>,
        @ViewBuilder overlay: @escaping (UIImage) -> Content
    ) -> some View {
        modifier(
            ZoomImageViewerModifier(
                uiImage: uiImage,
                dismissAction: ZoomImageDismissAction(binding: uiImage),
                /// Built here, while the view this modifies updates, so that view is updated whenever the image changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: uiImage.wrappedValue, content: overlay),
                sourceConfiguration: nil
            )
        )
    }

    /// Presents an image in a fullscreen viewer over this view with the built-in close button, fading the image in and out.
    ///
    /// ```swift
    /// .zoomImageViewer(uiImage: $uiImage)
    /// ```
    ///
    /// Use ``SwiftUICore/View/zoomImageViewer(uiImage:overlay:)`` with ``ZoomImageDefaultOverlay`` to add other views alongside the close button.
    /// - Parameters:
    ///   - uiImage: The image to present. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer, fading it out. Setting another image while the viewer is open replaces the one on screen.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    func zoomImageViewer(
        uiImage: Binding<UIImage?>,
        closeButtonPosition: Alignment = .topTrailing
    ) -> some View {
        zoomImageViewer(uiImage: uiImage) { _ in
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }

}

/// The source-matching configuration retained by an item-based viewer after its public inputs are normalized.
///
/// The item type identifies which descendant sources belong to the viewer even while it is closed. The presented identifier selects the source its image matches when it is open. A viewer created directly from a `UIImage` has no source configuration.
struct ZoomImageSourceConfiguration {
    /// The type of item shown by the sources that belong to this viewer.
    let itemType: ObjectIdentifier
    /// The identifier of the item the viewer is presenting, or `nil` when it is closed.
    ///
    /// Kept as its original type because SwiftUI does not match a type-erased `AnyHashable` to the underlying identifier.
    let presentedID: (any Hashable)?
}

/// The information source views need from a viewer that grows its image from them.
struct ZoomImageViewerInfo: Equatable {
    /// The namespace the viewer matches its image to a source in.
    let namespace: Namespace.ID
    /// The identifier of the item the viewer is presenting, or `nil` when it is closed.
    ///
    /// Type erased, as it is only compared with each source's identifier. The viewer matches its image by the identifier's own type.
    let presentedID: AnyHashable?
}

extension EnvironmentValues {
    /// The viewers above this view that grow their images from source views, by the type of item they present.
    ///
    /// Keyed by the type of item, so viewers of different types attached to the same view each find their own sources. A viewer below another of the same type replaces it, so a source belongs to the nearest one.
    @Entry var zoomImageViewers: [ObjectIdentifier: ZoomImageViewerInfo] = [:]
}

/// Places a viewer over the modified view and connects it to source views inside that view.
struct ZoomImageViewerModifier<Overlay: View>: ViewModifier {
    @Environment(\.zoomImageViewers) private var viewers
    @Environment(\.zoomImageViewerWrapper) private var wrapper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    @Binding var uiImage: UIImage?
    let dismissAction: ZoomImageDismissAction
    let overlay: Overlay
    /// Present for an item-based viewer, including while it is closed, or `nil` for a viewer created directly from a `UIImage`.
    let sourceConfiguration: ZoomImageSourceConfiguration?

    func body(content: Content) -> some View {
        if let sourceConfiguration {
            content
                .environment(\.zoomImageViewers, viewers.merging([sourceConfiguration.itemType: viewerInfo(for: sourceConfiguration)]) { $1 })
                .overlayPreferenceValue(ZoomImageSourceIDs.self) { sourceIDs in
                    wrapped(
                        ZoomImageViewerHost(
                            uiImage: $uiImage,
                            dismissAction: dismissAction,
                            overlay: overlay,
                            matchedGeometry: matchedGeometry(
                                for: sourceConfiguration,
                                onScreen: sourceIDs[sourceConfiguration.itemType] ?? []
                            ),
                            reduceMotionAtInsertion: reduceMotion
                        )
                        .animation(ZoomImageMatchedGeometry.landingAnimation(), value: uiImage != nil)
                    )
                }
                /// Sources inside belong to this viewer, not another viewer of the same item type further out.
                .transformPreference(ZoomImageSourceIDs.self) { sourceIDs in
                    sourceIDs[sourceConfiguration.itemType] = nil
                }
        } else {
            content.overlay {
                wrapped(
                    ZoomImageViewerHost(
                        uiImage: $uiImage,
                        dismissAction: dismissAction,
                        overlay: overlay,
                        matchedGeometry: nil,
                        reduceMotionAtInsertion: reduceMotion
                    )
                )
            }
        }
    }

    func viewerInfo(for sourceConfiguration: ZoomImageSourceConfiguration) -> ZoomImageViewerInfo {
        ZoomImageViewerInfo(
            namespace: namespace,
            presentedID: sourceConfiguration.presentedID.map { AnyHashable($0) }
        )
    }

    func matchedGeometry(
        for sourceConfiguration: ZoomImageSourceConfiguration,
        onScreen: Set<AnyHashable>
    ) -> ZoomImageMatchedGeometry? {
        guard let id = sourceConfiguration.presentedID, onScreen.contains(AnyHashable(id)) else { return nil }
        return ZoomImageMatchedGeometry(id: id, namespace: namespace)
    }

    /// The only point where the public wrapper's required type erasure enters normal viewer placement.
    @ViewBuilder
    func wrapped(_ viewer: some View) -> some View {
        if let wrapper {
            wrapper.wrap(ZoomImageViewerContent(viewer))
        } else {
            viewer
        }
    }
}
