//
//  GeometryProxy-extensions.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-05-04.
//

import SwiftUI

extension GeometryProxy {
    /// The size of this proxy's frame including its safe area insets.
    var sizeIncludingSafeAreaInsets: CGSize {
        size + CGSize(
            width: safeAreaInsets.leading + safeAreaInsets.trailing,
            height: safeAreaInsets.top + safeAreaInsets.bottom
        )
    }
}
