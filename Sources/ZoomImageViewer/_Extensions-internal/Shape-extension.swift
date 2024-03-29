//
//  Shape-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2021-01-11.
//

import SwiftUI

internal extension Shape {
    func scaleToFit(_ frame: CGSize, aspectRatio: CGFloat) -> some Shape {
        self
            .scale(x: aspectRatio > frame.aspectRatio ? 1 : frame.aspectRatio * aspectRatio, y: aspectRatio > frame.aspectRatio ? frame.aspectRatio / aspectRatio : 1, anchor: .center)
    }
}
