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
    /// The optional binding of the viewer this action closes, type erased without storing an escaping closure.
    private let binding: (any ZoomImageDismissibleBinding)?

    init<Value>(binding: Binding<Value?>) {
        self.binding = ZoomImageOptionalBinding(binding: binding)
    }

    init() {
        binding = nil
    }
    
    /// Closes the viewer.
    ///
    /// The viewer animates closing itself, including shrinking an image back into its source, so the binding is cleared in the current transaction.
    @MainActor
    public func callAsFunction() {
        binding?.dismiss()
    }
}

public extension EnvironmentValues {
    /// Closes the zoom image viewer this environment is in, or does nothing outside of one.
    @Entry var closeZoomImage = ZoomImageCloseAction()
}

/// A type-erased optional binding that can clear itself.
private protocol ZoomImageDismissibleBinding {
    @MainActor func dismiss()
}

private struct ZoomImageOptionalBinding<Value>: ZoomImageDismissibleBinding {
    let binding: Binding<Value?>

    @MainActor
    func dismiss() {
        binding.wrappedValue = nil
    }
}
