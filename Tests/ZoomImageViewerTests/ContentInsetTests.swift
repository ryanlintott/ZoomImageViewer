//
//  ContentInsetTests.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-11.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

/// A portrait phone frame in points, including its safe area.
private let frame = CGSize(width: 393, height: 852)

/// A portrait phone's safe area, as SwiftUI reports it when nothing is rotated.
private let portraitInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

/// The same safe area as SwiftUI reports it inside a view rotated a quarter turn, where the insets
/// have moved to the edges they now meet.
private let rotatedInsets = UIEdgeInsets(top: 0, left: 34, bottom: 0, right: 59)

/// The content inset is what carries the safe area, because `contentInsetAdjustmentBehavior` is
/// `.never`. Left to itself `UIScrollView` would use the window's insets, which belong to the wrong
/// edges whenever the content is rotated to an orientation the app does not support.
@MainActor
@Suite("ZoomImageViewRepresentable content insets")
struct ContentInsetTests {
    static func representable(safeAreaInsets: UIEdgeInsets) -> ZoomImageViewRepresentable {
        ZoomImageViewRepresentable(
            sizeIncludingSafeAreaInsets: frame,
            safeAreaInsets: safeAreaInsets,
            isInteractive: true,
            zoomState: .constant(.min),
            maximumZoomScale: 2,
            uiImage: UIImage()
        )
    }

    static func scrollView(contentSize: CGSize) -> UIScrollView {
        let scrollView = UIScrollView(origin: .zero, size: frame)
        scrollView.contentSize = contentSize
        return scrollView
    }

    @Test("An image larger than the frame is inset to the safe area")
    func overflowingImageUsesSafeArea() {
        let scrollView = Self.scrollView(contentSize: CGSize(width: 800, height: 1600))
        Self.representable(safeAreaInsets: portraitInsets).updateInset(scrollView)

        #expect(scrollView.contentInset == portraitInsets)
    }

    /// The insets have to follow the content through a rotation rather than staying on the window's
    /// edges, or a viewer rotated to an unsupported orientation keeps its top and bottom insets
    /// running across the screen.
    @Test("Rotated insets are used as given, not transposed back")
    func overflowingImageUsesRotatedSafeArea() {
        let scrollView = Self.scrollView(contentSize: CGSize(width: 800, height: 1600))
        Self.representable(safeAreaInsets: rotatedInsets).updateInset(scrollView)

        #expect(scrollView.contentInset == rotatedInsets)
    }

    /// An image that fits is a fullscreen image, so it is centred in the whole frame and drawn
    /// under the safe area rather than pushed out of it.
    @Test("An image smaller than the frame is centred, ignoring the safe area")
    func fittingImageIsCentred() {
        let contentSize = CGSize(width: 200, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        Self.representable(safeAreaInsets: portraitInsets).updateInset(scrollView)

        #expect(scrollView.contentInset.top == (frame.height - contentSize.height) / 2)
        #expect(scrollView.contentInset.left == (frame.width - contentSize.width) / 2)
    }

    /// Each axis is decided on its own, the same way `contentInsetAdjustmentBehavior` would.
    @Test("An image overflowing one axis is inset there and centred on the other")
    func axesAreDecidedSeparately() {
        let contentSize = CGSize(width: 800, height: 400)
        let scrollView = Self.scrollView(contentSize: contentSize)
        Self.representable(safeAreaInsets: portraitInsets).updateInset(scrollView)

        #expect(scrollView.contentInset.left == portraitInsets.left)
        #expect(scrollView.contentInset.right == portraitInsets.right)
        #expect(scrollView.contentInset.top == (frame.height - contentSize.height) / 2)
    }
}

private extension UIScrollView {
    convenience init(origin: CGPoint, size: CGSize) {
        self.init(frame: CGRect(origin: origin, size: size))
    }
}
