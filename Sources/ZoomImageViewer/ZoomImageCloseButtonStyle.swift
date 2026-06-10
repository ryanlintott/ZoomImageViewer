//
//  ZoomImageCloseButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2022-09-10.
//

import SwiftUI

/// A button style that allows for color, blend mode and padding adjustments.
public struct ZoomImageCloseButtonStyle: ButtonStyle {
    let color: Color?
    let blendMode: BlendMode?
    let paddingAmount: CGFloat?
    
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
        self.color = color
        self.blendMode = blendmode
        self.paddingAmount = paddingAmount
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(
                ZoomImageCloseButtonViewModifier(
                    color: color,
                    blendmode: blendMode,
                    paddingAmount: paddingAmount,
                    isPressed: configuration.isPressed
                )
            )
    }
}

struct ZoomImageCloseButtonViewModifier: ViewModifier {
    let color: Color
    let blendMode: BlendMode
    let paddingAmount: CGFloat
    let isPressed: Bool
    
    /// Creates a button style that allows for color, blend mode and padding adjustments.
    /// - Parameters:
    ///   - color: Color of the button label.
    ///   - blendmode: Defines how the button label will blend with the background.
    ///   - paddingAmount: Amount of outer padding on the button.
    init(
        color: Color? = nil,
        blendmode: BlendMode? = nil,
        paddingAmount: CGFloat? = nil,
        isPressed: Bool
    ) {
        self.color = color ?? .white
        self.blendMode = blendmode ?? .difference
        self.paddingAmount = paddingAmount ?? 10
        self.isPressed = isPressed
    }
    
    func body(content: Content) -> some View {
        content
            .font(.title)
            .labelStyle(.iconOnly)
            .foregroundColor(color)
            .opacity(isPressed ? 0.5 : 1)
            .blendMode(blendMode)
            .padding(paddingAmount)
            .contentShape(Rectangle())
    }
}

#Preview {
    Button {
        
    } label: {
        Label("Hello", systemImage: "xmark")
    }
    .buttonStyle(ZoomImageCloseButtonStyle(color: .blue, blendmode: .normal, paddingAmount: 10))
}
