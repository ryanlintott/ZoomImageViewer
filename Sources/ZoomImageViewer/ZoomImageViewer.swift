//
//  SwiftUIView.swift
//  
//
//  Created by Ryan Lintott on 2021-01-13.
//

import SwiftUI

public struct ZoomImageViewer: View {
    @Binding private var uiImage: UIImage?
    let closeButton: CloseButton?
    
    public init(uiImage: Binding<UIImage?>, closeButton: CloseButton? = nil) {
        self._uiImage = uiImage
        self.closeButton = closeButton
    }
    
    public var body: some View {
        #warning("Don't need this as FrameUp has fixed this issue.")
        /// This is added to prevent view offset on dismiss when using with rotationMatchingOrientation
        Color.clear.overlay(
            ZStack {
                if uiImage != nil {
                    FullScreenImageView(uiImage: $uiImage, closeButton: closeButton)
                }
            }
        )
    }
}
