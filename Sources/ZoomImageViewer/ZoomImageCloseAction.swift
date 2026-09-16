//
//  ZoomImageCloseAction.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// An action that closes the ``ZoomImageView`` a view is in.
///
/// Read it from the environment in a view inside the viewer's overlay, then call it like a function.
///
/// ```swift
/// struct DoneButton: View {
///     @Environment(\.closeZoomImage) private var closeZoomImage
///
///     var body: some View {
///         Button("Done", systemImage: "xmark", role: .close) {
///             closeZoomImage()
///         }
///     }
/// }
/// ```
///
/// Setting the viewer's image binding to `nil` closes it the same way, so a button that has the binding can do that instead.
///
/// Use this instead of `dismiss`. The viewer is an overlay rather than a presentation, so `dismiss` closes whatever presentation the viewer is in, like a sheet, and leaves the image showing.
///
/// Outside of a viewer it does nothing.
public struct ZoomImageCloseAction {
    /// The image binding of the viewer the action closes, or `nil` outside of a viewer.
    ///
    /// Stored rather than a closure, as closures cannot be compared, so every view reading the action would update whenever the viewer does. Clearing the binding is all closing takes, as the viewer fades out when its image is set to `nil`.
    let uiImage: Binding<UIImage?>?
    
    /// The animation the binding is cleared with, so an image with matched geometry shrinks back into its source, or `nil` to clear it in the current transaction.
    var animation: Animation? = nil
    
    /// Closes the viewer.
    @MainActor
    public func callAsFunction() {
        guard let uiImage else { return }
        
        if let animation {
            withAnimation(animation) {
                uiImage.wrappedValue = nil
            }
        } else {
            uiImage.wrappedValue = nil
        }
    }
}

public extension EnvironmentValues {
    /// Closes the ``ZoomImageView`` this environment is in, or does nothing outside of one.
    @Entry var closeZoomImage = ZoomImageCloseAction(uiImage: nil)
}
