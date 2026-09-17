//
//  Binding-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-16.
//

import SwiftUI

extension Binding {
    /// A binding to the image of the item this binding holds, which clears the item when the image is set to `nil`.
    ///
    /// Projected through a key path rather than made with `init(get:set:)`, so two bindings for the same item and image compare equal, and a viewer given the same ones as its last update can be left alone.
    func zoomImage<Item>(_ image: KeyPath<Item, UIImage>) -> Binding<UIImage?> where Value == Item? {
        self[dynamicMember: \.[zoomImage: image]]
    }
}

extension Optional {
    /// The image of the wrapped item, or `nil` when there is none. Setting it to `nil` clears the item, and setting an image does nothing, as the image belongs to the item.
    subscript(zoomImage image: KeyPath<Wrapped, UIImage>) -> UIImage? {
        get { self?[keyPath: image] }
        set {
            if newValue == nil {
                self = nil
            }
        }
    }
}
