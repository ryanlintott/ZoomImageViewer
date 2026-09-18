//
//  ZoomImageCloseAction.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// An action that closes the zoom image viewer a view is in.
///
/// For the built-in close button in a place of your choosing, use ``ZoomImageCloseButton``, which is already wired to this action and carries the system's localized label. Reach for this action when you want your own button with your own title, role or accessibility.
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
    
    /// Closes the viewer.
    ///
    /// The viewer animates closing itself, including shrinking an image back into its source, so the binding is cleared in the current transaction.
    @MainActor
    public func callAsFunction() {
        uiImage?.wrappedValue = nil
    }
}

public extension EnvironmentValues {
    /// Closes the zoom image viewer this environment is in, or does nothing outside of one.
    @Entry var closeZoomImage = ZoomImageCloseAction(uiImage: nil)
}
