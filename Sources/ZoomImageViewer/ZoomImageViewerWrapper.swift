//
//  ZoomImageViewerWrapper.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

public extension View {
    /// Wraps the zoom image viewer inside this view in another view, like `AutoRotatingView` from FrameUp.
    ///
    /// Set it once above the viewer, and the viewer is placed in the wrapper. The wrapper fills the view the viewer is attached to, and the viewer fills the wrapper.
    ///
    /// An app locked to portrait can let fullscreen images rotate by wrapping its viewer in `AutoRotatingView`:
    ///
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .zoomImageViewerWrapper { viewer in
    ///             AutoRotatingView { viewer }
    ///         }
    /// }
    /// ```
    ///
    /// A viewer that grows its image from a source view turns the image back as it lands, so it arrives square with its source whichever way the wrapper has turned it. A nearer wrapper replaces an outer one.
    ///
    /// The wrapper is type erased only at this environment boundary. SwiftUI environment values cannot store an arbitrary generic wrapper type, and keeping the erasure here prevents it from spreading into the viewer renderer or presentation state.
    /// - Parameter wrapper: Builds the view the viewer is placed in, from the viewer.
    func zoomImageViewerWrapper<Wrapper: View>(
        @ViewBuilder _ wrapper: @escaping (AnyView) -> Wrapper
    ) -> some View {
        environment(\.zoomImageViewerWrapper, ZoomImageViewerWrapper { AnyView(wrapper($0)) })
    }
}

/// The view the zoom image viewer below it is placed in.
struct ZoomImageViewerWrapper {
    let wrap: @MainActor (AnyView) -> AnyView
}

extension EnvironmentValues {
    /// The view the zoom image viewer below it is placed in, or `nil` to place the viewer directly over the view it is attached to.
    @Entry var zoomImageViewerWrapper: ZoomImageViewerWrapper? = nil
}
