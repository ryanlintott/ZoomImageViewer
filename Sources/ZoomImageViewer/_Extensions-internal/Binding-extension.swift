//
//  Binding-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-16.
//

import SwiftUI

extension Binding {
    /// A live binding to the image of the item this binding holds.
    ///
    /// Keeping this binding at the viewer boundary lets an overlay built from preferences observe the
    /// item change in the same transaction that removes the source stand-in for matched geometry.
    func zoomImage<Item>(_ image: KeyPath<Item, UIImage>) -> Binding<UIImage?> where Value == Item? {
        self[dynamicMember: \.[zoomImage: image]]
    }
}

extension Optional {
    /// The image of the wrapped item, or `nil` when there is none. Setting it to `nil` clears the item.
    subscript(zoomImage image: KeyPath<Wrapped, UIImage>) -> UIImage? {
        get { self?[keyPath: image] }
        set {
            if newValue == nil {
                self = nil
            }
        }
    }
}
