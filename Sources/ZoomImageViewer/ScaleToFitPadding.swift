//
//  ScaleToFitPadding.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// A shape covering the empty bars left around an image that has been scaled to fit a frame.
///
/// The path is empty when the image fills the frame exactly.
struct ScaleToFitPadding: Shape {
    var size: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = size.scaledToFit(rect.size)

        /// Amount of empty space on each side of the scaled image.
        let dx = (rect.width - size.width) / 2
        let dy = (rect.height - size.height) / 2

        /// Bars above and below the image.
        if dy > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: rect.width, height: dy))
            path.addRect(.init(x: rect.minX, y: rect.maxY - dy, width: rect.width, height: dy))
        }

        /// Bars to either side of the image.
        if dx > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: dx, height: rect.height))
            path.addRect(.init(x: rect.maxX - dx, y: rect.minY, width: dx, height: rect.height))
        }

        return path
    }
}
