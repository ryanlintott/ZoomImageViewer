//
//  ZoomImageSource.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-16.
//

import SwiftUI

public extension View {
    /// Makes this view the source a zoom image viewer's image grows from and shrinks back into, usually a thumbnail.
    ///
    /// Pass the item this view shows, using the same item type as the ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)`` above it. The view is matched to the viewer's image by the item's type and `id`. It is hidden while its item's image is showing, and fades back in once the image has landed on it again. It is never removed, so its layout doesn't change and any state inside it is kept.
    ///
    /// With Reduce Motion on, the image fades in and out rather than growing from this view, so the view stays visible the whole time.
    ///
    /// Hiding and fading back in follow the viewer's own timing, not the animation the item was set with, so the item doesn't need to be set inside `withAnimation`.
    ///
    /// ```swift
    /// Image(uiImage: photo.image)
    ///     .resizable()
    ///     .scaledToFit()
    ///     .zoomImageSource(for: photo)
    /// ```
    ///
    /// The image is fitted to this view's frame, so the view has to show the whole image, like one with `scaledToFit()`. A cropped view, like one with `scaledToFill()`, doesn't match the image as it starts growing or once it has landed.
    ///
    /// A view with no item-based viewer above it is left as it is. Attach only one viewer to a hierarchy containing source views. To present several kinds of item, wrap them in one enum and pass the corresponding enum case to both the viewer and each source.
    /// - Parameter item: The item this view shows.
    func zoomImageSource<Item: Identifiable>(for item: Item) -> some View {
        modifier(ZoomImageSourceModifier(id: ZoomImageSourceID(item)))
    }
}

/// Hides a source view while its image is showing, and gives the image an invisible stand-in of the same size to grow from and shrink back into.
///
/// Matched geometry only matches frames, so the view inserted and removed with the image doesn't have to be the content. The content stays where it is and only changes opacity, so it is built once and laid out once.
///
/// Reports its identifier to the viewer it belongs to, so the viewer only grows an image from a source that is on screen.
struct ZoomImageSourceModifier: ViewModifier {
    /// With Reduce Motion on, the viewer fades its image in and out rather than growing it from here, so the source view stays visible.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The viewer above this view that grows its image from source views.
    @Environment(\.zoomImageViewer) private var viewer

    let id: ZoomImageSourceID

    func body(content: Content) -> some View {
        /// Whether there is an item-based viewer only changes if one is added or removed above this view, so the branch taken normally stays the same.
        if let viewer {
            let isPresenting = viewer.presentedID == id

            content
                .opacity(isPresenting && !reduceMotion ? 0 : 1)
                /// Hidden at once as the image starts growing over it, and faded back in once the image has landed on it again.
                .animation(isPresenting ? nil : .linear(duration: ZoomImageMatchedGeometry.swapDuration).delay(ZoomImageMatchedGeometry.landingDelay), value: isPresenting)
                .overlay {
                    /// Removed in the transaction that sets the item and inserted in the one that clears it, so SwiftUI pairs it with the image being inserted or removed.
                    ///
                    /// Keeps the default transition, which can't be seen on a clear view. With `.identity`, SwiftUI doesn't pair the stand-in with the image as it is removed, and the image appears at full size instead of growing.
                    if !isPresenting {
                        Color.clear
                            .matchedGeometryEffect(id: id, in: viewer.namespace)
                    }
                }
                /// Inserts and removes the stand-in with the same spring the viewer grows and shrinks the image with, whatever animation the item was changed with, so the two sides of the match always animate together.
                .animation(ZoomImageMatchedGeometry.landingAnimation(), value: isPresenting)
                .preference(key: ZoomImageSourceIDs.self, value: [id])
        } else {
            content
        }
    }
}

/// The identifiers of the source views on screen.
///
/// Read by the viewer, which fades its image in and out when the item it presents has no source on screen, such as one scrolled out of a lazy grid, rather than growing it from nowhere.
struct ZoomImageSourceIDs: PreferenceKey {
    static var defaultValue: Set<ZoomImageSourceID> { [] }

    static func reduce(value: inout Set<ZoomImageSourceID>, nextValue: () -> Set<ZoomImageSourceID>) {
        value.formUnion(nextValue())
    }
}
