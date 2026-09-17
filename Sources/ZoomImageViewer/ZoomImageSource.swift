//
//  ZoomImageSource.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-16.
//

import SwiftUI

public extension View {
    /// Makes this view the source a ``ZoomImageView`` image grows from and shrinks back into, like a thumbnail.
    ///
    /// Pass the item this view shows, the value of the viewer's item binding as the selection, and the viewer's namespace. The view is hidden while its item's image is showing, and fades back in once the image has landed on it again. It is never removed, so its layout doesn't change and any state inside it is kept.
    ///
    /// ```swift
    /// Image(uiImage: photo.image)
    ///     .resizable()
    ///     .scaledToFit()
    ///     .zoomImageSource(for: photo, selection: selectedPhoto, in: namespace)
    /// ```
    ///
    /// The image is fitted to this view's frame, so a view that shows the whole image, like one with `scaledToFit()`, matches it most closely. See ``ZoomImageView/init(item:image:in:overlay:)`` for setting up the viewer.
    /// - Parameters:
    ///   - item: The item this view shows.
    ///   - selection: The item the viewer is presenting, or `nil` when it is closed.
    ///   - namespace: The namespace the viewer is in.
    func zoomImageSource<Item: Identifiable>(for item: Item, selection: Item?, in namespace: Namespace.ID) -> some View {
        modifier(ZoomImageSourceModifier(id: item.id, isPresenting: selection?.id == item.id, namespace: namespace))
    }
}

/// Hides a source view while its image is showing, and gives the image an invisible stand-in of the same size to grow from and shrink back into.
///
/// Matched geometry only matches frames, so the view inserted and removed with the image doesn't have to be the content. The content stays where it is and only changes opacity, so it is built once and laid out once.
struct ZoomImageSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let isPresenting: Bool
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .opacity(isPresenting ? 0 : 1)
            /// Hidden at once as the image starts growing over it, and faded back in once the image has landed on it again.
            .animation(isPresenting ? nil : .linear(duration: ZoomImageMatchedGeometry.swapDuration).delay(ZoomImageMatchedGeometry.landingDelay), value: isPresenting)
            .overlay {
                /// Removed in the transaction that sets the item and inserted in the one that clears it, so SwiftUI pairs it with the image being inserted or removed.
                ///
                /// Keeps the default transition, which can't be seen on a clear view. With `.identity`, SwiftUI doesn't pair the stand-in with the image as it is removed, and the image appears at full size instead of growing.
                if !isPresenting {
                    Color.clear
                        .matchedGeometryEffect(id: id, in: namespace)
                }
            }
    }
}
