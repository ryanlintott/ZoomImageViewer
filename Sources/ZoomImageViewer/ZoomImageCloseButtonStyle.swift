//
//  ZoomImageCloseButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2022-09-10.
//

import SwiftUI

/// A button style that allows for color, blend mode and padding adjustments.
///
/// Deprecated, as the overlay now hides while the image is zoomed in, so the close button no longer needs a discreet style. Use ``ZoomImageDefaultButtonStyle`` or a system button style instead.
@available(*, deprecated, message: "Use ZoomImageDefaultButtonStyle or a system button style, like .bordered.")
public struct ZoomImageCloseButtonStyle: ButtonStyle {
    let color: Color
    let blendMode: BlendMode
    let paddingAmount: CGFloat
    
    /// Creates a button style that allows for color, blend mode and padding adjustments.
    /// - Parameters:
    ///   - color: Color of the button label. (default: white)
    ///   - blendmode: Defines how the button label will blend with the background. (default: difference)
    ///   - paddingAmount: Amount of outer padding on the button. (default: 10)
    public init(
        color: Color? = nil,
        blendmode: BlendMode? = nil,
        paddingAmount: CGFloat? = nil
    ) {
        self.color = color ?? .white
        self.blendMode = blendmode ?? .difference
        self.paddingAmount = paddingAmount ?? 10
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .labelStyle(.iconOnly)
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .blendMode(blendMode)
            .padding(paddingAmount)
            .contentShape(Rectangle())
    }
}
