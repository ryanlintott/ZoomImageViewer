//
//  ZoomImageSourceID.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-21.
//

import Foundation

/// The identity a viewer and one of its source views use for matched geometry.
///
/// Includes the item type so unrelated items with equal identifiers cannot match accidentally.
struct ZoomImageSourceID: Hashable {
    let itemType: ObjectIdentifier
    let itemID: AnyHashable

    init<Item, ID: Hashable>(itemType: Item.Type, itemID: ID) {
        self.itemType = ObjectIdentifier(itemType)
        self.itemID = AnyHashable(itemID)
    }

    init<Item: Identifiable>(_ item: Item) {
        self.init(itemType: Item.self, itemID: item.id)
    }
}
