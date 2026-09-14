//
//  ScaleToFitPadding.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// A shape covering the empty bars left around an image that has been scaled to fit inside the safe area of a frame.
///
/// The bars are the same insets ``ZoomImageScrollView`` places around a zoomed out image, so the shape always leaves exactly the image uncovered. The path is empty when the image fills the frame exactly.
struct ScaleToFitPadding: Shape {
    var size: CGSize
    /// The safe area the image is fitted and centred inside, which is covered wherever the image leaves it empty.
    var safeAreaInsets: UIEdgeInsets = .zero

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let frame = SafeAreaFrame(size: rect.size, safeAreaInsets: safeAreaInsets)
        guard frame.safeSize.width > 0, frame.safeSize.height > 0 else { return path }
        
        /// Scaled with `scaledToFit(_:)` rather than a zoom scale, as it returns the safe size exactly when the aspect ratios match, where multiplying by a scale can leave a sliver of a bar.
        let insets = frame.insets(around: size.scaledToFit(frame.safeSize))

        /// Bars above and below the image.
        if insets.top > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: rect.width, height: insets.top))
        }
        if insets.bottom > 0 {
            path.addRect(.init(x: rect.minX, y: rect.maxY - insets.bottom, width: rect.width, height: insets.bottom))
        }

        /// Bars to either side of the image.
        if insets.left > 0 {
            path.addRect(.init(x: rect.minX, y: rect.minY, width: insets.left, height: rect.height))
        }
        if insets.right > 0 {
            path.addRect(.init(x: rect.maxX - insets.right, y: rect.minY, width: insets.right, height: rect.height))
        }

        return path
    }
}
