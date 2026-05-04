//
//  GeometryProxy-extensions.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-05-04.
//

import SwiftUI

extension GeometryProxy {
    var containerCornerInsetsIfAvailable: RectangleCornerInsetsIfAvailable {
        if #available(iOS 26, macOS 26, watchOS 26, visionOS 26, tvOS 26, *) {
            .init(containerCornerInsets)
        } else {
            .zero
        }
    }
    
    func horizontalContainerCornerInsetsIfAvailable(for position: Alignment) -> EdgeInsets {
        switch position {
        case .topLeading:
                .init(top: 0, leading: containerCornerInsetsIfAvailable.topLeading.width, bottom: 0, trailing: 0)
        case .topTrailing:
                .init(top: 0, leading: 0, bottom: 0, trailing: containerCornerInsetsIfAvailable.topTrailing.width)
        case .bottomLeading:
                .init(top: 0, leading: containerCornerInsetsIfAvailable.bottomLeading.width, bottom: 0, trailing: 0)
        case .bottomTrailing:
                .init(top: 0, leading: 0, bottom: 0, trailing: containerCornerInsetsIfAvailable.bottomTrailing.width)
        default:
                .init()
        }
    }
    
    func verticalContainerCornerInsetsIfAvailable(for position: Alignment) -> EdgeInsets {
        switch position {
        case .topLeading:
                .init(top: containerCornerInsetsIfAvailable.topLeading.height, leading: 0, bottom: 0, trailing: 0)
        case .topTrailing:
                .init(top: containerCornerInsetsIfAvailable.topTrailing.height, leading: 0, bottom: 0, trailing: 0)
        case .bottomLeading:
                .init(top: 0, leading: 0, bottom: containerCornerInsetsIfAvailable.bottomLeading.height, trailing: 0)
        case .bottomTrailing:
                .init(top: 0, leading: 0, bottom: containerCornerInsetsIfAvailable.bottomTrailing.height, trailing: 0)
        default:
                .init()
        }
    }
}

struct RectangleCornerInsetsIfAvailable {
    var topLeading: CGSize
    var topTrailing: CGSize
    var bottomLeading: CGSize
    var bottomTrailing: CGSize
    
    static let zero: Self = .init(topLeading: .zero, topTrailing: .zero, bottomLeading: .zero, bottomTrailing: .zero)
}

@available(iOS 26, macOS 26, watchOS 26, visionOS 26, tvOS 26, *)
extension RectangleCornerInsetsIfAvailable {
    init(_ insets: RectangleCornerInsets) {
        self.init(
            topLeading: insets.topLeading,
            topTrailing: insets.topTrailing,
            bottomLeading: insets.bottomLeading,
            bottomTrailing: insets.bottomTrailing
        )
    }
}
