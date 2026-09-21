//
//  ZoomImageDismissAction.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

/// An action that dismisses the zoom image viewer a view is in.
///
/// For the built-in close button in a place of your choosing, use ``ZoomImageCloseButton``, which is already wired to this action and carries the system's localized label. Reach for this action when you want your own button with your own title, role or accessibility.
///
/// Read it from the environment in a view inside the viewer's overlay, then call it like a function.
///
/// ```swift
/// struct DoneButton: View {
///     @Environment(\.dismissZoomImage) private var dismissZoomImage
///
///     var body: some View {
///         Button("Done", systemImage: "xmark", role: .close) {
///             dismissZoomImage()
///         }
///     }
/// }
/// ```
///
/// Setting the viewer's image binding to `nil` dismisses it the same way, so a button that has the binding can do that instead.
///
/// Use this instead of SwiftUI's `dismiss`. The viewer is an overlay rather than a system presentation, so `dismiss` closes whatever presentation the viewer is in, like a sheet, and leaves the image showing.
///
/// Outside of a viewer it does nothing.
public struct ZoomImageDismissAction {
    /// The optional binding of the viewer this action dismisses, type erased without storing an escaping closure.
    private let binding: (any Dismissible)?

    init<Value>(binding: Binding<Value?>) {
        self.binding = DismissibleBinding(binding: binding)
    }

    init() {
        binding = nil
    }
    
    /// Dismisses the viewer.
    ///
    /// The viewer animates closing itself, including shrinking an image back into its source, so the binding is cleared in the current transaction.
    @MainActor
    public func callAsFunction() {
        binding?.dismiss()
    }
}

public extension EnvironmentValues {
    /// Dismisses the zoom image viewer this environment is in, or does nothing outside of one.
    @Entry var dismissZoomImage = ZoomImageDismissAction()
}

/// A value that can dismiss the viewer.
private protocol Dismissible {
    @MainActor func dismiss()
}

/// An optional binding that dismisses the viewer by clearing itself.
private struct DismissibleBinding<Value>: Dismissible {
    let binding: Binding<Value?>

    @MainActor
    func dismiss() {
        binding.wrappedValue = nil
    }
}
