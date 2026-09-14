//
//  ScaleToFitPadding.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// A shape covering the empty bars left around an image that has been scaled to fit inside the safe area of a frame.
///
/// The path is empty when the image fills the frame exactly.
struct ScaleToFitPadding: Shape {
    var size: CGSize
    /// The safe area the image is fitted and centred inside, which is covered wherever the image leaves it empty.
    var safeAreaInsets: UIEdgeInsets = .zero

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let safeSize = CGSize(
            width: rect.width - safeAreaInsets.left - safeAreaInsets.right,
            height: rect.height - safeAreaInsets.top - safeAreaInsets.bottom
        )
        guard safeSize.width > 0, safeSize.height > 0 else { return path }
        
        let size = size.scaledToFit(safeSize)

        /// Amount of empty space either side of the scaled image inside the safe area.
        let dx = (safeSize.width - size.width) / 2
        let dy = (safeSize.height - size.height) / 2
        
        /// Empty space on each edge of the frame, safe area included. Worked out from sizes rather than positions so an image that fills an edge leaves exactly nothing to cover there.
        let top = safeAreaInsets.top + dy
        let bottom = safeAreaInsets.bottom + dy
        let left = safeAreaInsets.left + dx
        let right = safeAreaInsets.right + dx

        /// Bars above and below the image.
        if top > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: rect.width, height: top))
        }
        if bottom > 0 {
            path.addRect(.init(x: rect.minX, y: rect.maxY - bottom, width: rect.width, height: bottom))
        }

        /// Bars to either side of the image.
        if left > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: left, height: rect.height))
        }
        if right > 0 {
            path.addRect(.init(x: rect.maxX - right, y: rect.minY, width: right, height: rect.height))
        }

        return path
    }
}
