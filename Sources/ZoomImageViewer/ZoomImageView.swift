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
    let closeButtonStyle: CloseButtonStyle
    let closeButtonPosition: Alignment
    
    /// Creates a view with a zoomable image and a close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    public init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle, closeButtonPosition: Alignment = .topLeading) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
        self.closeButtonPosition = closeButtonPosition
    }
    
    public var body: some View {
        if uiImage != nil {
            _ZoomImageView(uiImage: $uiImage, closeButtonStyle: closeButtonStyle, closeButtonPosition: closeButtonPosition)
        }
    }
}

public extension ZoomImageView<ZoomImageCloseButtonStyle> {
    /// Creates a view with a zoomable image and a default close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonPosition: The close button position within the entire viewable frame.
    init(uiImage: Binding<UIImage?>, closeButtonPosition: Alignment = .topLeading) {
        self._uiImage = uiImage
        self.closeButtonStyle = ZoomImageCloseButtonStyle()
        self.closeButtonPosition = closeButtonPosition
    }
}
