//
//  ZoomImageDefaultButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// The button style a ``ZoomImageView`` gives the buttons in its overlay, unless they set their own.
///
/// It looks like a Glass button in iOS 26. Earlier versions show the label's icon large, which draws ``ZoomImageCloseButton`` as a white xmark on a blurred dark circle inside a viewer, where the dark colour scheme is forced.
///
/// Used outside a ``ZoomImageView`` it follows the colour scheme it is given like any other style.
public struct ZoomImageDefaultButtonStyle: ButtonStyle {
    /// Creates the default button style for a ``ZoomImageView`` overlay.
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            configuration.label
                .font(.title3)
                .labelStyle(.iconOnly)
                .padding(12)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            standardBody(configuration: configuration)
        }
        #else
        standardBody(configuration: configuration)
        #endif
    }
    
    /// The look used before iOS 26, like a standard close button over media.
    ///
    /// The colours come from whatever colour scheme the style is given. A ``ZoomImageView`` forces the dark one on its whole overlay, to match a background that is black in both light and dark mode, so inside a viewer these are always the colours for a dark background. The palette puts the primary colour on the xmark and a material behind it, and a symbol with a single layer is drawn in the primary colour.
    func standardBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.title)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.secondary, .ultraThinMaterial)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .padding(10)
            .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        
//        Color.black
        
        VStack {
            Button {
                
            } label: {
                Label {
                    Text(verbatim: "Hello")
                } icon: {
                    Image(systemName: "xmark")
                }
            }
            .buttonStyle(ZoomImageDefaultButtonStyle())
        }
    }
}

@available(*, deprecated, renamed: "ZoomImageDefaultButtonStyle")
public typealias ZoomImageDefaultCloseButtonStyle = ZoomImageDefaultButtonStyle
