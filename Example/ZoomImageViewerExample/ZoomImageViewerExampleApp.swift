//
//  ZoomImageViewerExampleApp.swift
//  ZoomImageViewerExample
//
//  Created by Ryan Lintott on 2021-01-13.
//

import FrameUp
import SwiftUI
import ZoomImageViewer

@main
struct ZoomImageViewerExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                /// `AutoRotatingView` is from FrameUp, and is optional. It lets an app that only uses portrait show fullscreen images in landscape as well.
                .zoomImageViewerWrapper { viewer in
                    AutoRotatingView { viewer }
                }
        }
    }
}
