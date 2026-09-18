//
//  ZoomImageCloseButton.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2025-07-28.
//

import SwiftUI

/// The built-in close button for a zoom image viewer.
///
/// On iOS 26 and up it uses the close role with the label the system provides, which the system localizes. Earlier versions use an xmark in a filled circle titled "Close", localized by this package.
///
/// It has no button style or position of its own. Inside a viewer it uses ``ZoomImageDefaultButtonStyle`` unless you give it another with `buttonStyle(_:)`. Use ``ZoomImageDefaultOverlay`` for the button in its default position.
///
/// ```swift
/// .zoomImageViewer(uiImage: $uiImage) { _ in
///     ZoomImageCloseButton()
///         .buttonStyle(.glass)
///         .padding()
///         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
/// }
/// ```
public struct ZoomImageCloseButton: View {
    @Environment(\.closeZoomImage) private var closeZoomImage
    
    /// Creates the built-in close button, which closes the zoom image viewer it is in.
    public init() {}
    
    func action() {
        closeZoomImage()
    }
    
    public var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
        } else {
            legacyButton
        }
        #else
        legacyButton
        #endif
    }
    
    /// Button used before iOS 26, where there is no close role with a system provided label.
    var legacyButton: some View {
        Button(role: .cancel, action: action) {
            Label {
                Text("Close", bundle: .module, comment: "Title of the button that dismisses the fullscreen image viewer. Shown as an xmark icon and read by VoiceOver.")
            } icon: {
                /// The circle comes from the icon rather than the button style, so other icon buttons in the overlay don't gain one.
                Image(systemName: "xmark.circle.fill")
            }
        }
    }
}


@available(iOS 26, *)
#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        
        VStack {
            ZoomImageCloseButton()
                .buttonStyle(ZoomImageDefaultButtonStyle())
            
            ZoomImageCloseButton()
                .buttonStyle(.borderedProminent)
        }
    }
}
