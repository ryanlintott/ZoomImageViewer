//
//  ZoomImageView.swift
//  ZoomImageView
//
//  Created by Ryan Lintott on 2021-01-13.
//

import SwiftUI

/// A view for displaying fullscreen images that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture.
///
/// Close button style is customizable.
public struct ZoomImageView<CloseButtonStyle: ButtonStyle>: View {
    @Binding private var uiImage: UIImage?
    let closeButtonStyle: CloseButtonStyle?
    
    /// Creates a view with a zoomable image and a close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    public init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle?) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
    }
    
    public var body: some View {
        if uiImage != nil {
            _ZoomImageView(uiImage: $uiImage, closeButtonStyle: closeButtonStyle)
        }
    }
}

public extension ZoomImageView<ZoomImageCloseButtonStyle> {
    /// Creates a view with a zoomable image and a default close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    init(uiImage: Binding<UIImage?>) {
        self._uiImage = uiImage
        self.closeButtonStyle = nil
    }
}
