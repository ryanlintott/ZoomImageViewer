//
//  CGFloat-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

extension CGFloat {
    /// The value `progress` of the way from this value to `end`, carrying on past `end` when `progress` is above 1.
    func interpolated(to end: CGFloat, progress: CGFloat) -> CGFloat {
        self + (end - self) * progress
    }
}
