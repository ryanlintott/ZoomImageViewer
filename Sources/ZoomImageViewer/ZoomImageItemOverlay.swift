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
public struct ZoomImageItemOverlay<Item, Content: View>: View {
    /// The overlay built for the current item, or `nil` once the item is cleared.
    let content: Content?

    /// Builds the overlay for the last item while the viewer fades out.
    ///
    /// The closure from the latest update, which is the one that cleared the item, so everything it captured is current.
    let makeContent: (Item) -> Content

    let item: Item?

    /// The last item the overlay was shown for, kept while the viewer fades out and dropped along with the overlay once the image is removed.
    @State private var lastItem = LastItem()

    init(item: Item?, @ViewBuilder content: @escaping (Item) -> Content) {
        self.item = item
        self.content = item.map(content)
        self.makeContent = content
    }

    public var body: some View {
        /// Recorded here rather than in `onChange(of:)`, as an item is not necessarily `Equatable`, and one changed without changing its identifier would otherwise leave an old copy to fade out with. Only read once the item is cleared, so this never changes what is drawn in the update that records it.
        let _ = item.map { lastItem.item = $0 }

        /// A single optional expression, so the overlay keeps its identity and state as it switches to the last item at the start of the fade out.
        content ?? lastItem.item.map(makeContent)
    }

    /// Holds the last item without updating the overlay when it is recorded.
    final class LastItem {
        var item: Item?
    }
}
