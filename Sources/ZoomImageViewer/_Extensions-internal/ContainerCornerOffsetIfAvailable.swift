//
//  ContainerCornerOffsetIfAvailable.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-14.
//

import SwiftUI

extension View {
    nonisolated func containerCornerOffsetIfAvailable(_ edges: Edge.Set, sizeToFit: Bool = false) -> some View {
        #if compiler(>=6.2)
        ifAvailable {
            if #available(iOS 26, *) {
                $0.containerCornerOffset(edges, sizeToFit: sizeToFit)
            }
        }
        #else
        self
        #endif
    }
}
