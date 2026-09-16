//
//  ZoomImageContentRotation.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-15.
//

import SwiftUI

/// How far the viewer's content is turned from the window it is in, and the point it turns around.
///
/// A viewer inside a container that rotates its content, like `AutoRotatingView` from FrameUp, is drawn turned while the window stays put. Matched geometry only matches rectangles, so SwiftUI moves the image straight to its source's rectangle and the container turns that result, leaving the image sideways and away from its source. Turning the image back by this as it lands undoes the container's turn.
struct ZoomImageContentRotation: Equatable {
    /// The angle the content is drawn at, measured from the window.
    var angle: Angle = .zero

    /// The point the content turns around, as a unit point of the frame the image fills.
    var anchor: UnitPoint = .center

    /// An unturned rotation, for a viewer that is square with its window or has not been measured yet.
    init() { }
    
    /// Whether the content is turned far enough from the window to be worth undoing.
    var isRotated: Bool {
        abs(angle.radians) > 0.001
    }

    /// The rotation of a view drawn with `transform`, which maps points in the view to points in its window, or an unturned rotation when the view is not turned.
    ///
    /// The angle is the direction the view's own x axis points in the window. The anchor is the one point the transform leaves where it is, which is the point the container turns its content around, worked out by solving `transform(point) == point`. A transform with no turn leaves no such point, so the rotation falls back to nothing to undo.
    /// - Parameters:
    ///   - transform: The transform from the view's coordinate space to its window's.
    ///   - size: The size of the view, used to describe the anchor as a unit point.
    init(transform: CGAffineTransform, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        angle = .radians(atan2(transform.b, transform.a))
        guard isRotated else { return }

        /// The fixed point solves `(I - A)p = t`, where `A` is the transform's rotation and scale and `t` its translation.
        let determinant = (1 - transform.a) * (1 - transform.d) - transform.c * transform.b
        guard abs(determinant) > 0.000001 else {
            angle = .zero
            return
        }

        let point = CGPoint(
            x: ((1 - transform.d) * transform.tx + transform.c * transform.ty) / determinant,
            y: (transform.b * transform.tx + (1 - transform.a) * transform.ty) / determinant
        )
        anchor = UnitPoint(x: point.x / size.width, y: point.y / size.height)
    }
}

/// A view that reports how far the content around it is turned from its window.
///
/// A `UIView` is used as it can be asked for its own transform to the window, which accounts for every container between the two, however the turn was applied. The view is always in the hierarchy, even while no image is showing, so the rotation is current when an image appears.
struct ZoomImageRotationReader: UIViewRepresentable {
    @Binding var rotation: ZoomImageContentRotation

    func makeUIView(context: Context) -> ZoomImageRotationReadingView {
        let view = ZoomImageRotationReadingView()
        view.isUserInteractionEnabled = false
        view.onChange = { rotation = $0 }
        return view
    }

    func updateUIView(_ uiView: ZoomImageRotationReadingView, context: Context) {
        /// Replaced on every update, as the closure writes to a binding this view holds.
        uiView.onChange = { rotation = $0 }
    }
}

final class ZoomImageRotationReadingView: UIView {
    var onChange: ((ZoomImageContentRotation) -> Void)?

    /// The rotation last reported, so an unchanged one is not reported again.
    private var reportedRotation: ZoomImageContentRotation?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportRotation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportRotation()
    }

    /// The transform from this view's coordinate space to its window's, worked out from where the corner of the view and the two axes leading away from it land.
    private var transformToWindow: CGAffineTransform {
        let origin = convert(CGPoint.zero, to: nil)
        let alongX = convert(CGPoint(x: 1, y: 0), to: nil)
        let alongY = convert(CGPoint(x: 0, y: 1), to: nil)

        return CGAffineTransform(
            a: alongX.x - origin.x, b: alongX.y - origin.y,
            c: alongY.x - origin.x, d: alongY.y - origin.y,
            tx: origin.x, ty: origin.y
        )
    }

    private func reportRotation() {
        guard window != nil else { return }

        let rotation = ZoomImageContentRotation(transform: transformToWindow, size: bounds.size)
        guard rotation != reportedRotation else { return }
        reportedRotation = rotation

        /// Reported after the layout pass it was measured in, as SwiftUI ignores state changed while it is updating a view.
        let onChange = onChange
        Task { @MainActor in
            onChange?(rotation)
        }
    }
}

/// Turns an image back to the window as it lands on its source.
///
/// Used by a transition rather than applied to the view, as SwiftUI leaves a view being removed as it was and animates only the transition it is given. A rotation set on the view itself, or on anything around it, is applied to a removed image at once instead.
struct ZoomImageTurnModifier: ViewModifier, Animatable {
    /// How far the image is through its landing, from 0 where it is now to 1 where it ends up.
    var progress: Double

    /// The rotation undone as the image lands, so it arrives square with the window its source is in.
    var rotation: ZoomImageContentRotation

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.rotationEffect(.radians(-rotation.angle.radians * progress), anchor: rotation.anchor)
    }
}
