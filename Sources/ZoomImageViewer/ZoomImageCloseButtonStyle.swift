//
//  ZoomImageCloseButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2022-09-10.
//

import SwiftUI

/// A button style that allows for color, blend mode and padding adjustments.
public struct ZoomImageCloseButtonStyle: ButtonStyle {
    let color: Color
    let blendMode: BlendMode
    let paddingAmount: CGFloat
    
    /// Creates a button style that allows for color, blend mode and padding adjustments.
    /// - Parameters:
    ///   - color: Color of the button label.
    ///   - blendmode: Defines how the button label with blend with the background.
    ///   - paddingAmount: Amount of outer padding on the button.
    public init(color: Color = .white, blendmode: BlendMode = .difference, paddingAmount: CGFloat = 10) {
        self.color = color
        self.blendMode = blendmode
        self.paddingAmount = paddingAmount
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .blendMode(blendMode)
            .padding(paddingAmount)
    }
}
