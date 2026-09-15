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
public struct ZoomImageCloseAction: Equatable {
    /// Identifies the viewer the action closes.
    let id: UUID?
    let action: @MainActor () -> Void
    
    init(id: UUID?, action: @escaping @MainActor () -> Void) {
        self.id = id
        self.action = action
    }
    
    /// Closes the viewer.
    @MainActor
    public func callAsFunction() {
        action()
    }
    
    /// Compared by viewer rather than by action, as actions cannot be compared. Otherwise every view reading the action would update whenever the viewer does.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

public extension EnvironmentValues {
    /// Closes the ``ZoomImageView`` this environment is in, or does nothing outside of one.
    @Entry var closeZoomImage = ZoomImageCloseAction(id: nil) {}
}
