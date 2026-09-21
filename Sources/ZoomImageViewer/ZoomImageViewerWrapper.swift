//
//  ZoomImageViewerWrapper.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

public extension View {
    /// Wraps every zoom image viewer inside this view in another view, like `AutoRotatingView` from FrameUp.
    ///
    /// Set it once near the root of the app, and every viewer below it is placed in the wrapper. The wrapper fills the view the viewer is attached to, and the viewer fills the wrapper.
    ///
    /// An app locked to portrait can let fullscreen images rotate by wrapping its viewers in `AutoRotatingView`:
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
        @ViewBuilder _ wrapper: @escaping (ZoomImageViewerContent) -> Wrapper
    ) -> some View {
        environment(\.zoomImageViewerWrapper, ZoomImageViewerWrapper { AnyView(wrapper($0)) })
    }
}

/// The view every zoom image viewer below it is placed in.
struct ZoomImageViewerWrapper {
    let wrap: @MainActor (ZoomImageViewerContent) -> AnyView
}

extension EnvironmentValues {
    /// The view every zoom image viewer below it is placed in, or `nil` to place viewers directly over the view they are attached to.
    @Entry var zoomImageViewerWrapper: ZoomImageViewerWrapper? = nil
}
