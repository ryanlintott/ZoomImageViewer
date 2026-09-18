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
    /// The overlay is the only way to close the viewer other than dragging the image away, so include a close button. ``ZoomImageCloseButton`` closes the viewer it is in, and your own buttons can do the same with the ``SwiftUICore/EnvironmentValues/closeZoomImage`` action.
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
                /// Built here, while the view this modifies updates, so that view is updated whenever the item changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: item.wrappedValue, content: overlay),
                sources: ZoomImageViewerSources(itemType: ObjectIdentifier(Item.self), presentedID: item.wrappedValue?.id)
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
                /// Built here, while the view this modifies updates, so that view is updated whenever the image changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: uiImage.wrappedValue, content: overlay),
                sources: nil
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

    /// Wraps every zoom image viewer inside this view in another view, like `AutoRotatingView` from FrameUp.
    ///
    /// Set it once near the root of the app, and every viewer attached with ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)`` or its other forms below it is placed in the wrapper. The wrapper fills the view the viewer is attached to, and the viewer fills the wrapper.
    ///
    /// An app locked to portrait can let fullscreen images rotate by wrapping its viewers in `AutoRotatingView`:
    ///
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .zoomImageViewerWrapper { viewer in
    ///             AutoRotatingView { viewer }
    ///         }
    /// }
    /// ```
    ///
    /// A viewer that grows its image from a source view turns the image back as it lands, so it arrives square with its source whichever way the wrapper has turned it.
    ///
    /// A wrapper set further in replaces this one for the viewers inside it.
    /// - Parameter wrapper: Builds the view the viewer is placed in, from the viewer.
    func zoomImageViewerWrapper<Wrapper: View>(
        @ViewBuilder _ wrapper: @escaping (ZoomImageViewerContent) -> Wrapper
    ) -> some View {
        environment(\.zoomImageViewerWrapper, ZoomImageViewerWrapper { AnyView(wrapper($0)) })
    }
}

/// A zoom image viewer, as passed to the closure given to ``SwiftUICore/View/zoomImageViewerWrapper(_:)`` to place in a wrapper.
public struct ZoomImageViewerContent: View {
    /// Type erased, as the wrapper is stored in the environment and so can't know the type of any one viewer.
    let viewer: AnyView

    init(_ viewer: some View) {
        self.viewer = AnyView(viewer)
    }

    public var body: some View {
        viewer
    }
}

/// The view every zoom image viewer below it is placed in.
struct ZoomImageViewerWrapper {
    let wrap: @MainActor (ZoomImageViewerContent) -> AnyView
}

extension EnvironmentValues {
    /// The view every zoom image viewer below it is placed in, or `nil` to place viewers directly over the view they are attached to.
    @Entry var zoomImageViewerWrapper: ZoomImageViewerWrapper? = nil
}

/// The item type and presented item of a viewer that grows its images from source views.
struct ZoomImageViewerSources {
    /// The type of item the viewer presents, which its source views show.
    let itemType: ObjectIdentifier
    /// The identifier of the item being presented, or `nil` when the viewer is closed.
    ///
    /// Kept as its own type rather than an `AnyHashable`, as SwiftUI only matches identifiers of the same type.
    let presentedID: (any Hashable)?
}

/// Places a viewer over the view it modifies and, for a viewer with source views, hands the sources inside that view the viewer's namespace and presented item.
///
/// The sources are inside the view this modifies and the viewer is in its overlay, so both are inside this modifier and share its namespace without the caller declaring one.
struct ZoomImageViewerModifier<Overlay: View>: ViewModifier {
    /// The viewers above this view that grow their images from source views, by the type of item they present. A viewer replaces the one for its type of item for the sources inside it.
    @Environment(\.zoomImageSourceViewers) private var viewers
    @Environment(\.zoomImageViewerWrapper) private var wrapper
    @Namespace private var namespace

    @Binding var uiImage: UIImage?
    let overlay: Overlay
    /// The item type and presented item of a viewer that grows its images from source views, or `nil` for one that fades them in and out. Comes from the modifier's form, so it is only ever `nil` or never `nil` for the life of the viewer.
    let sources: ZoomImageViewerSources?

    func body(content: Content) -> some View {
        if let sources {
            content
                /// Set in the same update that sets the item, so each source removes its stand-in in the transaction that inserts the image and SwiftUI grows the image from it.
                .environment(\.zoomImageSourceViewers, viewers.merging([sources.itemType: sourceViewer(for: sources)]) { $1 })
                .overlayPreferenceValue(ZoomImageSourceIDs.self) { sourceIDs in
                    wrapped(
                        _ZoomImageView(uiImage: $uiImage, overlay: overlay, matchedGeometry: matchedGeometry(for: sources, onScreen: sourceIDs[sources.itemType] ?? []))
                            /// Grows and shrinks the image with the landing spring whatever animation the binding was changed with, matching the one its source's stand-in is inserted and removed with.
                            .animation(ZoomImageMatchedGeometry.landingAnimation(), value: uiImage != nil)
                    )
                }
                /// The sources inside belong to this viewer, so a viewer of the same type further out doesn't see them and fades its images in and out.
                .transformPreference(ZoomImageSourceIDs.self) { sourceIDs in
                    sourceIDs[sources.itemType] = nil
                }
        } else {
            content
                .overlay {
                    wrapped(
                        _ZoomImageView(uiImage: $uiImage, overlay: overlay, matchedGeometry: nil)
                    )
                }
        }
    }

    /// This viewer as seen by the sources inside the view it modifies.
    func sourceViewer(for sources: ZoomImageViewerSources) -> ZoomImageSourceViewer {
        ZoomImageSourceViewer(namespace: namespace, presentedID: sources.presentedID.map { AnyHashable($0) })
    }

    /// The matched geometry effect for the presented item, or `nil` when there is none or its source isn't on screen.
    /// - Parameter onScreen: The identifiers of this viewer's sources that are on screen.
    func matchedGeometry(for sources: ZoomImageViewerSources, onScreen: Set<AnyHashable>) -> ZoomImageMatchedGeometry? {
        guard let id = sources.presentedID, onScreen.contains(AnyHashable(id)) else { return nil }
        return ZoomImageMatchedGeometry(id: id, namespace: namespace)
    }

    /// Places the viewer in the wrapper from the environment, if there is one.
    @ViewBuilder
    func wrapped(_ viewer: some View) -> some View {
        if let wrapper {
            wrapper.wrap(ZoomImageViewerContent(viewer))
        } else {
            viewer
        }
    }
}
