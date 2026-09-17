//
//  ZoomImageItemOverlay.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-16.
//

import SwiftUI

/// The overlay of a ``ZoomImageView`` presenting an item, built for the item on screen.
///
/// Created by ``ZoomImageView/init(item:image:in:overlay:)``, which builds the overlay for the current item while the view creating the viewer updates, so any state the overlay reads is tracked by that view from its first update. Clearing the item fades the viewer out, and the overlay keeps showing the last item it had until it is gone rather than going blank.
public struct ZoomImageItemOverlay<Item: Equatable, Content: View>: View {
    /// The overlay built for the current item, or `nil` once the item is cleared.
    let content: Content?

    /// Builds the overlay for the last item while the viewer fades out.
    ///
    /// The closure from the latest update, which is the one that cleared the item, so everything it captured is current.
    let makeContent: (Item) -> Content

    let item: Item?

    /// The last item the overlay was shown for, kept while the viewer fades out and dropped along with the overlay once the image is removed.
    ///
    /// Starts as the item the overlay is created with, as the overlay is only in the hierarchy while an image is showing.
    @State private var lastItem: Item?

    init(item: Item?, @ViewBuilder content: @escaping (Item) -> Content) {
        self.item = item
        self.content = item.map(content)
        self.makeContent = content
        self._lastItem = State(initialValue: item)
    }

    public var body: some View {
        /// A single optional expression, so the overlay keeps its identity and state as it switches to the last item at the start of the fade out.
        (content ?? lastItem.map(makeContent))
            .onChange(of: item) { newItem in
                /// Read from the new value, as this closure sees the view from before the change and its `item` is the previous one. Compared as a whole item rather than by `id`, so an item edited without changing its `id` fades out with its latest contents. Left alone when the item is cleared.
                if let newItem {
                    lastItem = newItem
                }
            }
    }
}
