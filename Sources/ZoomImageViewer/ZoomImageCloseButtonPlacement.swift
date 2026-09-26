//
//  ZoomImageCloseButtonPlacement.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-25.
//

import SwiftUI

/// Where the default overlay puts its close button in the whole frame of the viewer, safe area included, so it sits where a system close button on a fullscreen sheet would, clear of the system UI the container reserves.
///
/// The button is laid out in a slot. Its padding is measured from the edges of the whole frame, and a slot dimension that's `nil` takes the button's own size. Frames are in the whole frame's layout-relative coordinate space, so leading is at zero in either layout direction.
///
/// - The system's vertical bar, like on iPhone Duo, is a side of the frame the safe area is inset from by exactly the width of a reserved region along it. The button goes at the top of the bar, below any reserved region there and at least ``barMargin`` from the top, centred ``barItemCentreInset`` from that side's outer edge, where the system centres its bar items.
/// - A top corner outside the safe area, where the top inset is made by reserved regions or there is none, holds the button concentric with the corner, centred ``barItemCentreInset`` from the top and the side. A reserved region in the way, like the status bar on an unfolded iPhone Duo, moves it along the top to beside the region.
/// - Anywhere else the button is padded from the safe area.
struct ZoomImageCloseButtonPlacement: Equatable {
    /// Where the button sits within the whole frame.
    var alignment: Alignment
    /// The distance from each edge of the whole frame to the slot.
    var padding: EdgeInsets
    /// The width of the slot the button is centred in, or `nil` for the button's own width.
    var slotWidth: CGFloat?
    /// The height of the slot the button is centred in, or `nil` for the button's own height.
    var slotHeight: CGFloat?

    /// The space between the button and the edges of the safe area.
    static let padding: CGFloat = 16
    /// How far the system keeps the items in its vertical bar from the edges of the window, measured on iPhone Duo. FrameUp's `TabMenu` keeps the same margin.
    static let barMargin: CGFloat = 24
    /// How far the system centres its bar items and its close button from the edges of the window: its margin plus half of a 48 point item, measured on iPhone Duo. FrameUp's `TabMenu` centres its vertical items the same way.
    static let barItemCentreInset: CGFloat = barMargin + 48 / 2
    /// How far apart two positions can be and still count as the same, to absorb rounding in measured frames.
    static let tolerance: CGFloat = 1

    /// Places the button in the corner or along the edge it's given, or where a system close button would go when given `nil`.
    /// - Parameters:
    ///   - position: The close button position within the whole frame, or `nil` for the top of the system's vertical bar, on whichever side it is, and the top trailing corner where there's no bar.
    ///   - size: The size of the whole frame.
    ///   - safeAreaInsets: The safe area insets of the whole frame.
    ///   - occlusionFrames: The frames of the reserved regions that occlude the whole frame, like the status bar and camera, in its layout-relative coordinate space.
    init(position: Alignment?, size: CGSize, safeAreaInsets: EdgeInsets, occlusionFrames: [CGRect]) {
        let barEdge = Self.verticalBarEdge(size: size, safeAreaInsets: safeAreaInsets, occlusionFrames: occlusionFrames)
        let position = position ?? (barEdge == .leading ? .topLeading : .topTrailing)
        alignment = position
        padding = EdgeInsets(
            top: safeAreaInsets.top + Self.padding,
            leading: safeAreaInsets.leading + Self.padding,
            bottom: safeAreaInsets.bottom + Self.padding,
            trailing: safeAreaInsets.trailing + Self.padding
        )

        guard let side = Self.topCornerSide(position) else { return }

        /// A slot twice the inset, against the edge of the frame, centres the button the inset from it.
        let centredSlot = 2 * Self.barItemCentreInset
        if side == barEdge {
            /// Below any system UI at the top of the bar, and at least the bar's margin from the top.
            let column = Self.band(along: side, width: safeAreaInsets[Edge(side)], in: size)
            let systemUIBottom = occlusionFrames
                .filter { $0.minY < Self.tolerance && $0.intersects(column) }
                .map(\.maxY)
                .max() ?? 0
            padding[Edge(side)] = 0
            slotWidth = centredSlot
            padding.top = max(systemUIBottom, Self.barMargin)
        } else if Self.topIsOutsideSafeArea(safeAreaInsets: safeAreaInsets, occlusionFrames: occlusionFrames) {
            /// Concentric with the corner, or beside any system UI in the way.
            let corner = Self.band(along: side, width: centredSlot, in: size)
                .intersection(CGRect(x: 0, y: 0, width: size.width, height: centredSlot))
            let systemUIWidth = occlusionFrames
                .filter { $0.intersects(corner) }
                .map { Self.distance(from: side, to: $0, in: size) }
                .max()
            padding.top = 0
            slotHeight = centredSlot
            if let systemUIWidth {
                padding[Edge(side)] = systemUIWidth
            } else {
                padding[Edge(side)] = 0
                slotWidth = centredSlot
            }
        }
    }

    /// The side of the frame the system's vertical bar is on, or `nil` where there's no bar.
    ///
    /// The bar is a column the safe area makes room for along a side, with reserved regions as wide as the column in it, like the status bar and camera at its top or bottom. `toolbarVerticalEdge` isn't used, as it names the edge of the unturned interface, which a wrapper that turns the viewer can put along its top or bottom. The trailing side wins where both look like a bar.
    static func verticalBarEdge(size: CGSize, safeAreaInsets: EdgeInsets, occlusionFrames: [CGRect]) -> HorizontalEdge? {
        [HorizontalEdge.trailing, .leading].first { side in
            let width = safeAreaInsets[Edge(side)]
            guard width > 0 else { return false }
            let column = band(along: side, width: width, in: size)
            return occlusionFrames.contains { frame in
                abs(frame.minX - column.minX) < tolerance && abs(frame.maxX - column.maxX) < tolerance
            }
        }
    }

    /// Whether the top of the frame is free to use outside the safe area: there's no top inset, or reserved regions along the top make it, so it's there for system UI in part of the top rather than all of it.
    static func topIsOutsideSafeArea(safeAreaInsets: EdgeInsets, occlusionFrames: [CGRect]) -> Bool {
        safeAreaInsets.top < tolerance || occlusionFrames.contains { frame in
            frame.minY < tolerance && frame.maxY > safeAreaInsets.top - tolerance
        }
    }

    /// The side of a top corner position, or `nil` for any other position.
    static func topCornerSide(_ position: Alignment) -> HorizontalEdge? {
        switch position {
        case .topLeading: .leading
        case .topTrailing: .trailing
        default: nil
        }
    }

    /// A band of the frame's full height along a side.
    static func band(along side: HorizontalEdge, width: CGFloat, in size: CGSize) -> CGRect {
        CGRect(x: side == .leading ? 0 : size.width - width, y: 0, width: width, height: size.height)
    }

    /// The distance from a side of the frame to the far side of a frame within it.
    static func distance(from side: HorizontalEdge, to frame: CGRect, in size: CGSize) -> CGFloat {
        side == .leading ? frame.maxX : size.width - frame.minX
    }
}

extension Edge {
    init(_ edge: HorizontalEdge) {
        self = edge == .leading ? .leading : .trailing
    }
}

extension EdgeInsets {
    subscript(edge: Edge) -> CGFloat {
        get {
            switch edge {
            case .top: top
            case .leading: leading
            case .bottom: bottom
            case .trailing: trailing
            }
        }
        set {
            switch edge {
            case .top: top = newValue
            case .leading: leading = newValue
            case .bottom: bottom = newValue
            case .trailing: trailing = newValue
            }
        }
    }
}
