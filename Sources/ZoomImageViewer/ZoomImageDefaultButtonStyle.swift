//
//  ZoomImageDefaultButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// The button style a ``ZoomImageView`` gives the buttons in its overlay, unless they set their own.
///
/// It looks like a Glass button in iOS 26 and ``ZoomImageCloseButtonStyle`` in its default mode in any earlier version.
public struct ZoomImageDefaultButtonStyle: ButtonStyle {
    /// Creates the default button style for a ``ZoomImageView`` overlay.
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                #if compiler(>=6.2)
                .font(.title3)
                .labelStyle(.iconOnly)
                .padding(12)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
                #else
                .modifier(ZoomImageCloseButtonViewModifier(isPressed: configuration.isPressed))
                #endif
        } else {
            configuration.label
                .modifier(ZoomImageCloseButtonViewModifier(isPressed: configuration.isPressed))
        }
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
