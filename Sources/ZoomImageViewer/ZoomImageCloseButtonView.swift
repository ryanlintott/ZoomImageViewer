//
//  ZoomImageCloseButtonView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

struct ZoomImageCloseButtonView<CloseButtonStyle: ButtonStyle>: View {
    let closeButtonStyle: CloseButtonStyle?
    let opacity: Double
    let onClose: () -> Void
    
    var closeLabel: some View {
        Label("Close", systemImage: "xmark")
    }
    
    var baseButton: some View {
        if #available(iOS 15, *) {
            Button(role: .cancel) {
                onClose()
            } label: {
                closeLabel
            }
        } else {
            Button {
                onClose()
            } label: {
                closeLabel
            }
        }
    }
    
    var body: some View {
        ZStack {
            if let closeButtonStyle {
                baseButton
                    .buttonStyle(closeButtonStyle)
            } else if #available(iOS 26, *) {
                #if swift(>=6.2)
                baseButton
                    .buttonStyle(ZoomImageGlassCloseButtonStyle())
                #else
                baseButton
                    .buttonStyle(ZoomImageCloseButtonStyle())
                #endif
            } else {
                baseButton
                    .buttonStyle(ZoomImageCloseButtonStyle())
            }
        }.opacity(opacity)
    }
}


@available(iOS 26, *)
#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        
        Color.black
        
        VStack {
            ZoomImageCloseButtonView(closeButtonStyle: nil as ZoomImageCloseButtonStyle?, opacity: 1) {
                /// Close
            }
            
            ZoomImageCloseButtonView(closeButtonStyle: ZoomImageCloseButtonStyle(), opacity: 1) {
                /// Close
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        
            
    }
//    .sheet(isPresented: .constant(true)) {
//        NavigationStack {
//            Color.clear
//                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button(role: .cancel) { }
//                    }
//                    
//                    ToolbarItem(placement: .confirmationAction) {
//                        Button(role: .confirm) { }
//                    }
//                }
//        }
//        .presentationDetents([.fraction(0.4)])
//    }
}
