//
//  ZoomImageViewer.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

public extension View {
    /// Presents an item's image in a fullscreen viewer over this view that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture, growing the image from the item's source view and shrinking it back when it closes.
    ///
    /// The viewer covers this view, so attach it to a view that fills the screen. The image ignores the safe area, filling the whole frame and panning to its edges when zoomed in.
    ///
    /// Each thumbnail view inside this view can have the ``SwiftUICore/View/zoomImageSource(id:)`` modifier with its item's `id`. When a presented item's identifier matches, the image grows from and shrinks back to the source. An item with no matching source view fades in and out instead. The viewer handles these transitions, so change the item without `withAnimation`.
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
    ///                     .zoomImageSource(id: photo.id)
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
    /// ## Overlay
    ///
    /// Zooming in or panning hides the overlay and system UI. A single tap shows or hides the overlay at any zoom and the system UI while the image is fully zoomed out. They return automatically when the image is zoomed back out to fit.
    ///
    /// Buttons in it use ``ZoomImageDefaultButtonStyle`` unless they set their own style. Placing and padding the views is up to you. Use ``ZoomImageDefaultOverlay`` to keep the default close button with padding.
    ///
    /// The overlay is the only way to dismiss the viewer other than dragging the image away, so include a close button. ``ZoomImageCloseButton`` dismisses the viewer it is in, and your own buttons can use the ``SwiftUICore/EnvironmentValues/dismissZoomImage`` action.
    ///
    /// The viewer uses a black background in both light and dark mode and forces the dark colour scheme throughout the overlay.
    ///
    /// ## Multiple Item Types
    ///
    /// The viewer presents one normalized item type. To present several kinds of item, wrap them in one `Identifiable` and `Equatable` enum and give each case its own identifier case. Pass those identifiers to the corresponding source views.
    ///
    /// ## Accessibility
    ///
    /// With VoiceOver, the viewer is modal and the escape gesture closes it. The image is described by the `UIImage`'s `accessibilityLabel`. On iOS 16 and later, VoiceOver users can zoom and pan the image.
    ///
    /// With Reduce Motion on, the image fades in and out rather than growing from a source view.
    ///
    /// ## Rotation on Portrait-Only Interfaces
    ///
    /// Use ``ZoomImageViewerWrapper`` to wrap the viewer in `AutoRotatingView` from [FrameUp](https://github.com/ryanlintott/FrameUp), allowing images to rotate to orientations the app does not otherwise support.
    ///
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer. `Equatable`, so the overlay can tell when the item changes and fade out with its latest contents.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does, as a different instance is shown as a replacement image.
    ///   - wrapper: A type that places this viewer in another view, or `nil` to place it directly over the modified view. Defaults to `nil`.
    ///   - overlay: The views shown over the image for an item, stacked on top of each other.
    func zoomImageViewer<Item: Identifiable & Equatable, Content: View>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        wrapper: (any ZoomImageViewerWrapper.Type)? = nil,
        @ViewBuilder overlay: @escaping (Item) -> Content
    ) -> some View {
        modifier(
            ZoomImageViewerModifier(
                uiImage: item.zoomImage(image),
                dismissAction: ZoomImageDismissAction(binding: item),
                /// Built here, while the view this modifies updates, so that view is updated whenever the item changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: item.wrappedValue, content: overlay),
                sourceState: item.wrappedValue.map {
                    .presented(id: AnyHashable($0.id))
                } ?? .inactive,
                wrapper: wrapper
            )
        )
    }

    /// Presents an item's image in a fullscreen viewer over this view with the built-in close button, growing the image from the item's source view and shrinking it back when it closes.
    ///
    /// See ``SwiftUICore/View/zoomImageViewer(item:image:wrapper:overlay:)`` for how the viewer works and how to set up the source views. Use it with ``ZoomImageDefaultOverlay`` to add other views alongside the close button.
    ///
    /// ```swift
    /// .zoomImageViewer(item: $selectedPhoto, image: \.image)
    /// ```
    /// - Parameters:
    ///   - item: The item whose image is presented. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer.
    ///   - image: The item's image. It should return the same `UIImage` instance every time it is read, like a stored property does, as a different instance is shown as a replacement image.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    ///   - wrapper: A type that places this viewer in another view, or `nil` to place it directly over the modified view. Defaults to `nil`.
    func zoomImageViewer<Item: Identifiable & Equatable>(
        item: Binding<Item?>,
        image: KeyPath<Item, UIImage>,
        closeButtonPosition: Alignment = .topTrailing,
        wrapper: (any ZoomImageViewerWrapper.Type)? = nil
    ) -> some View {
        zoomImageViewer(item: item, image: image, wrapper: wrapper) { _ in
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }

    /// Presents an image in a fullscreen viewer over this view, fading the image in and out, with a custom overlay that receives the image.
    ///
    /// An image has nothing to match a source view by, so it always fades in and out. Present an `Identifiable` item with ``SwiftUICore/View/zoomImageViewer(item:image:wrapper:overlay:)`` to grow the image from a source view instead, or when the overlay needs more than the image, like a caption.
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
    /// See ``SwiftUICore/View/zoomImageViewer(item:image:wrapper:overlay:)`` for how the viewer and overlay work.
    /// - Parameters:
    ///   - uiImage: The image to present. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer, fading it out. Setting another image while the viewer is open replaces the one on screen.
    ///   - wrapper: A type that places this viewer in another view, or `nil` to place it directly over the modified view. Defaults to `nil`.
    ///   - overlay: The views shown over the image, stacked on top of each other.
    func zoomImageViewer<Content: View>(
        uiImage: Binding<UIImage?>,
        wrapper: (any ZoomImageViewerWrapper.Type)? = nil,
        @ViewBuilder overlay: @escaping (UIImage) -> Content
    ) -> some View {
        modifier(
            ZoomImageViewerModifier(
                uiImage: uiImage,
                dismissAction: ZoomImageDismissAction(binding: uiImage),
                /// Built here, while the view this modifies updates, so that view is updated whenever the image changes, and any state the overlay reads is tracked by it.
                overlay: ZoomImageItemOverlay(item: uiImage.wrappedValue, content: overlay),
                sourceState: .unavailable,
                wrapper: wrapper
            )
        )
    }

    /// Presents an image in a fullscreen viewer over this view with the built-in close button, fading the image in and out.
    ///
    /// ```swift
    /// .zoomImageViewer(uiImage: $uiImage)
    /// ```
    ///
    /// See ``SwiftUICore/View/zoomImageViewer(item:image:wrapper:overlay:)`` for more details on how the viewer works.
    /// Use it with ``ZoomImageDefaultOverlay`` to add other views alongside the close button.
    /// - Parameters:
    ///   - uiImage: The image to present. Closing the viewer sets it to `nil`, and setting it to `nil` closes the viewer, fading it out. Setting another image while the viewer is open replaces the one on screen.
    ///   - closeButtonPosition: The close button position within the entire viewable frame. Defaults to the top trailing corner.
    ///   - wrapper: A type that places this viewer in another view, or `nil` to place it directly over the modified view. Defaults to `nil`.
    func zoomImageViewer(
        uiImage: Binding<UIImage?>,
        closeButtonPosition: Alignment = .topTrailing,
        wrapper: (any ZoomImageViewerWrapper.Type)? = nil
    ) -> some View {
        zoomImageViewer(uiImage: uiImage, wrapper: wrapper) { _ in
            ZoomImageDefaultOverlay(closeButtonPosition: closeButtonPosition)
        }
    }

}

/// The viewer's relationship with source views after its public inputs are normalized.
enum ZoomImageSourceState {
    /// The viewer was created directly from a `UIImage` and cannot match a source.
    case unavailable
    /// The item-based viewer is closed but remains connected to its source views.
    case inactive
    /// The item-based viewer is presenting the source with this identifier.
    case presented(id: AnyHashable)

    /// Whether the viewer supports matching an item to a source view.
    var supportsSourceMatching: Bool {
        switch self {
        case .unavailable: false
        case .inactive, .presented: true
        }
    }

    /// The identifier of the source currently presented by the viewer, or `nil` when no source is presented.
    var presentedID: AnyHashable? {
        switch self {
        case .unavailable, .inactive: nil
        case .presented(let id): id
        }
    }
    
    func context(namespace: Namespace.ID) -> ZoomImageSourceContext? {
        switch self {
        case .unavailable:
            nil
        case .inactive, .presented:
            ZoomImageSourceContext(
                namespace: namespace,
                presentedID: presentedID
            )
        }
    }
    
    func matchedGeometry(sourceIDs: Set<AnyHashable>, in namespace: Namespace.ID) -> ZoomImageMatchedGeometry? {
        guard let presentedID,
              sourceIDs.contains(presentedID)
        else { return nil }
        return ZoomImageMatchedGeometry(id: presentedID, namespace: namespace)
    }
}

/// The source-matching context an item-based viewer provides to its descendant source views.
///
/// The shared namespace connects each source to the viewer's matched-geometry transition. `presentedID` identifies the source currently represented by the viewer, or is `nil` while the viewer is closed.
struct ZoomImageSourceContext: Equatable {
    /// The matched-geometry namespace shared by the viewer and its source views.
    let namespace: Namespace.ID
    /// The identifier of the source currently presented by the viewer, or `nil` while the viewer is closed.
    let presentedID: AnyHashable?
}

extension EnvironmentValues {
    /// The nearest item-based viewer's source-matching context.
    @Entry var zoomImageSourceContext: ZoomImageSourceContext? = nil
}

/// Places a viewer over the modified view and connects it to source views inside that view.
struct ZoomImageViewerModifier<Overlay: View>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    @Binding var uiImage: UIImage?
    let dismissAction: ZoomImageDismissAction
    let overlay: Overlay
    /// Whether this viewer can match a source and, when presenting an item, which source it matches.
    let sourceState: ZoomImageSourceState
    /// An uncommon container applied only to this viewer, or `nil` for the generic placement path.
    let wrapper: (any ZoomImageViewerWrapper.Type)?

    var landingAnimation: Animation? {
        sourceState.supportsSourceMatching ? ZoomImageMatchedGeometry.landingAnimation() : nil
    }

    func body(content: Content) -> some View {
        content
            .environment(\.zoomImageSourceContext, sourceState.context(namespace: namespace))
            .overlayPreferenceValue(ZoomImageSourceIDs.self) { sourceIDs in
                wrapped(
                    ZoomImageViewerHost(
                        uiImage: $uiImage,
                        dismissAction: dismissAction,
                        overlay: overlay,
                        matchedGeometry: sourceState.matchedGeometry(sourceIDs: sourceIDs, in: namespace),
                        reduceMotionAtInsertion: reduceMotion
                    )
                    .animation(landingAnimation, value: uiImage != nil)
                )
            }
    }

    /// The only point where an explicitly supplied wrapper's required type erasure enters viewer placement.
    @ViewBuilder
    func wrapped(_ viewer: some View) -> some View {
        if let wrapper {
            wrapper.wrap(AnyView(viewer))
        } else {
            viewer
        }
    }
}
