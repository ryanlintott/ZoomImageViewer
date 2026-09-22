//
//  ZoomImageViewerWrapper.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// A type that places a zoom image viewer in another view.
///
/// Pass the type to a `zoomImageViewer` modifier's `wrapper` parameter. This keeps uncommon container behavior local to that viewer instead of placing a closure in the environment.
///
/// An app locked to portrait can let fullscreen images rotate by defining a wrapper for `AutoRotatingView` from FrameUp:
///
/// ```swift
/// enum AutoRotatingViewerWrapper: ZoomImageViewerWrapper {
///     static func wrap(_ viewer: AnyView) -> AnyView {
///         AnyView(AutoRotatingView { viewer })
///     }
/// }
/// ```
///
/// Then pass it to the viewer:
///
/// ```swift
/// .zoomImageViewer(
///     item: $selectedPhoto,
///     image: \.image,
///     wrapper: AutoRotatingViewerWrapper.self
/// )
/// ```
///
/// A viewer that grows its image from a source view turns the image back as it lands, so it arrives square with its source whichever way the wrapper has turned it.
///
/// The viewer is type erased only when a wrapper is supplied. The wrapper view returned here can own state like any other SwiftUI view; the wrapper type itself is stable configuration stored directly by the viewer modifier.
public protocol ZoomImageViewerWrapper {
    /// Places the viewer in another view and erases the resulting wrapper view's type.
    ///
    /// - Parameter viewer: The type-erased zoom image viewer to place in the wrapper.
    /// - Returns: The type-erased wrapper containing the viewer.
    @MainActor static func wrap(_ viewer: AnyView) -> AnyView
}
