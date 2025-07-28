//
//  ScaleToFitPadding.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

struct ScaleToFitPadding: Shape {
    var size: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = size.scaledToFit(rect.size)
        
        let halfRemainingSize = CGSize(
            width: rect.width == size.width ? rect.width : (rect.width - size.width) / 2,
            height: rect.height == size.height ? rect.height : (rect.height - size.height) / 2
        )

        // Draw two rects covering the
        path.addRect(.init(origin: .zero, size: halfRemainingSize))
        path.addRect(.init(origin: .init(x: rect.maxX - halfRemainingSize.width, y: rect.maxY - halfRemainingSize.height), size: halfRemainingSize))
        
        return path
    }
}
