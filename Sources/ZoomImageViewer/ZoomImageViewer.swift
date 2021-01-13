//
//  SwiftUIView.swift
//  
//
//  Created by Ryan Lintott on 2021-01-13.
//

#if os(iOS)
import SwiftUI

public struct ZoomImageViewer: View {
    @Binding private var uiImage: UIImage?
    let closeButton: CloseButton?
    
    init(uiImage: Binding<UIImage?>, closeButton: CloseButton? = nil) {
        self._uiImage = uiImage
        self.closeButton = closeButton
    }
    
    @ViewBuilder
    public var body: some View {
        if uiImage != nil {
            FullScreenImageView(uiImage: $uiImage, closeButton: closeButton)
        } else {
            EmptyView()
        }
    }
}
#endif
