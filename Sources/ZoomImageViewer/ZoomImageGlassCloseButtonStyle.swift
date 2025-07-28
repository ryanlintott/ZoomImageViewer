//
//  ZoomImageGlassCloseButtonStyle.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

#if swift(>=6.2)
@available(iOS 26, *)
/// A button style that allows for color, blend mode and padding adjustments.
public struct ZoomImageGlassCloseButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .labelStyle(.iconOnly)
            .padding(12)
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

@available(iOS 26, *)
#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        
//        Color.black
        
        VStack {
            Button {
                
            } label: {
                Label("Hello", systemImage: "xmark")
            }
            .buttonStyle(ZoomImageGlassCloseButtonStyle())
        }
    }
}
#endif
