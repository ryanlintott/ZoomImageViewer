//
//  ZoomImageCanvas.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// Renders and interacts with the fullscreen image inside a viewer screen.
struct ZoomImageCanvas: View {
    /// Used to resolve the leading and trailing edges VoiceOver scrolls towards before they are handed to UIKit.
    @Environment(\.layoutDirection) private var layoutDirection

    @Binding var presentation: ZoomImagePresentationState

    let request: ZoomImagePresentationRequest
    let uiImage: UIImage
    let viewerSize: CGSize
    let contentRotation: ContentRotation
    let dismissAction: ZoomImageDismissAction

    /// How long the viewer takes to fade out, and a thrown image takes to leave the screen.
    let fadeDuration: TimeInterval

    private enum Constants {
        /// How long the overlay takes to hide or show.
        static let chromeDuration: TimeInterval = 0.25
        static let dismissThreshold: CGFloat = 200
        static let opacityAtDismissThreshold: Double = 0.8
        /// How far a dismissed image travels at least, as a multiple of the viewer's longest side.
        static let dismissDistanceMultiplier: CGFloat = 2
    }

    @GestureState private var isDragging = false

    private var matchedGeometry: ZoomImageMatchedGeometry? {
        presentation.matchedGeometry(for: request)
    }

    private var dismissalMatchedGeometry: ZoomImageMatchedGeometry? {
        presentation.dismissalMatchedGeometry(for: request)
    }

    private var isShowingImage: Bool {
        presentation.isShowingImage(for: request)
    }

    private var presentationOffset: CGSize {
        presentation.presentationOffset(for: request)
    }

    var body: some View {
        ZStack {
            /// Keeps the stack filling the frame while a matched image is removed ahead of the rest of the viewer.
            Color.clear

            if isShowingImage {
                /// Fills the viewer's frame around the image, so the transition's turn has the same anchor point whatever size the image is at.
                ZStack {
                    ZoomImageViewRepresentable(
                        isInteractive: presentation.isInteractive,
                        uiImage: uiImage,
                        frameSize: viewerSize,
                        maximumZoomScale: 2,
                        zoomState: $presentation.zoomState,
                        isZoomedIn: $presentation.isZoomedIn.animation(.easeInOut(duration: Constants.chromeDuration)),
                        isShowingOverlay: $presentation.isShowingOverlay.animation(.easeInOut(duration: Constants.chromeDuration)),
                        accessibilityScrollRequest: presentation.accessibilityScrollRequest
                    )
                    /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out.
                    .id(ObjectIdentifier(uiImage))
                    /// Outside the image identity above, so a replacement image doesn't grow from a source of its own.
                    .matchedGeometryEffect(matchedGeometry)
                }
                /// A removed image keeps the offset where it was released. SwiftUI drops offsets outside a view being removed.
                .offset(presentationOffset)
                .id(presentation.canvasID)
                .transition(imageTransition)
            }
        }
        .accessibilityIgnoresInvertColors()
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(Text(uiImage.accessibilityLabel ?? ""))
        .accessibilityInputLabels([
            Text("Image", bundle: .module, comment: "Voice Control input label for the fullscreen image, a name people can say to target it, as in “Tap Image”. Photo and Picture are alternative names for it, so a different common word for each works best."),
            Text("Photo", bundle: .module, comment: "Voice Control input label for the fullscreen image, a name people can say to target it, as in “Tap Photo”. Image and Picture are alternative names for it, so a different common word for each works best."),
            Text("Picture", bundle: .module, comment: "Voice Control input label for the fullscreen image, a name people can say to target it, as in “Tap Picture”. Image and Photo are alternative names for it, so a different common word for each works best.")
        ])
        .ifAvailable {
            if #available(iOS 16, *) {
                $0.accessibilityZoomAction { action in
                    switch action.direction {
                    case .zoomIn:
                        accessibilityZoom(.zoomIn, center: CGPoint(cgSize: viewerSize / 2))
                    case .zoomOut:
                        accessibilityZoom(.zoomOut, center: .zero)
                    }
                }
            }
        }
        .accessibilityScrollAction { edge in
            accessibilityScroll(towards: edge)
        }
        .accessibilityAction(named: presentation.isShowingOverlay
            ? Text("Hide Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that hides the controls shown over it.")
            : Text("Show Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that shows the controls over it after they were hidden.")
        ) {
            toggleOverlay()
        }
        .simultaneousGesture(dragImageGesture, isEnabled: presentation.zoomState == .min)
        .onChange(of: isDragging) { newValue in
            if !newValue {
                endDrag()
            }
        }
    }

    var dragImageGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, gestureState, _ in
                gestureState = true
            }
            .onChanged { value in
                recordDragValue(value)
                dragImage(translation: value.translation)
            }
            /// Records the final velocity, which the last change may not have had.
            .onEnded { value in
                recordDragValue(value)
            }
    }

    /// How the image is added and removed.
    ///
    /// An image with no source has nothing to land on, so it fades in and out with the animation that shows or clears it.
    var imageTransition: AnyTransition {
        let transition = matchedGeometry.map(ZoomImagePresentationTransition.matched) ?? .fade
        return transition.imageTransition(
            undoing: contentRotation,
            moving: -presentationOffset,
            velocity: presentation.dragVelocity
        )
    }

    /// Shows or hides the overlay for an assistive technology, the same as a single tap.
    ///
    /// Ignored while the image is being dragged away, which already fades the overlay out.
    func toggleOverlay() {
        guard presentation.isInteractive else { return }
        withAnimation(.easeInOut(duration: Constants.chromeDuration)) {
            presentation.isShowingOverlay.toggle()
        }
    }

    /// Zooms in or out for an assistive technology.
    ///
    /// Like a double tap, zooming in goes straight to the maximum and zooming out goes straight back to fit, as the maximum is only twice the fitted size. Ignored while the image is being dragged away.
    ///
    /// Zooming in always centres on the middle of the screen rather than where the gesture happened. VoiceOver's gestures can be performed anywhere on screen, so their location says nothing about the part of the image someone wants to see.
    /// - Parameter center: The middle of the viewer, measured from the top left corner of its frame.
    @available(iOS 16, *)
    func accessibilityZoom(_ direction: AccessibilityZoomGestureAction.Direction, center: CGPoint) {
        guard presentation.isInteractive else { return }

        switch direction {
        case .zoomIn:
            if case .max = presentation.zoomState { return }
            presentation.zoomState = .max(center: center)
        case .zoomOut:
            presentation.zoomState = .min
        }
    }

    /// Scrolls a zoomed in image towards `edge` for an assistive technology.
    ///
    /// Ignored while the image is being dragged away. A zoomed out image fits the screen, so the scroll view has nowhere to move it.
    func accessibilityScroll(towards edge: Edge) {
        guard presentation.isInteractive else { return }
        presentation.accessibilityScrollRequest = AccessibilityScrollRequest(
            edge: UIRectEdge(accessibilityScrollEdge: edge, layoutDirection: layoutDirection)
        )
    }

    /// Keeps where the drag is heading and how fast, for when it ends.
    func recordDragValue(_ value: DragGesture.Value) {
        if #available(iOS 17, *) {
            presentation.dragVelocity = value.velocity
        }
        presentation.predictedEndTranslation = value.predictedEndTranslation
    }

    func dragImage(translation: CGSize) {
        /// Hides the overlay as the drag starts, so nothing moves around over the image while it is dragged. It only comes back if the image is put back.
        if presentation.isInteractive {
            withAnimation(.easeInOut(duration: Constants.chromeDuration)) {
                presentation.overlayOpacity = 0
            }
        }
        presentation.isInteractive = false
        presentation.dragOffset = translation
        presentation.backgroundOpacity = 1 - Double(translation.magnitude / Constants.dismissThreshold) * (1 - Constants.opacityAtDismissThreshold)
    }

    /// Dismisses the image when the drag was heading far enough away, or puts it back otherwise.
    ///
    /// Called when the drag's gesture state resets rather than from the gesture's `onEnded`, so a drag that is cancelled is put back too.
    ///
    /// Reads the drag's predicted end and velocity from state, which is current even from the `onChange(of:perform:)` closure that calls this.
    func endDrag() {
        guard presentation.predictedEndTranslation.magnitude > Constants.dismissThreshold else {
            presentation.isInteractive = true
            withAnimation(.easeOut) {
                presentation.backgroundOpacity = 1
                presentation.overlayOpacity = 1
                presentation.dragOffset = .zero
                presentation.predictedEndTranslation = .zero
                presentation.dragVelocity = nil
            }
            return
        }

        let dismissalTransition: ZoomImagePresentationTransition
        /// A matched image shrinks back into its source from wherever it was dragged to, rather than being thrown off screen, with the viewer's own landing animation. Its offset is left where the drag put it and taken back to nothing by the transition, which carries on at the speed the drag was let go at. A change to the offset here would be applied to the removed image at once rather than animated, dragging it back to the middle of the frame before it sets off.
        if let dismissalMatchedGeometry {
            dismissalTransition = .matched(dismissalMatchedGeometry)
        } else {
            /// Lasts as long as the background's fade, so the image is off the screen by the time the background is gone.
            let toss = DismissToss(
                offset: presentation.dragOffset,
                velocity: presentation.dragVelocity,
                predictedEndTranslation: presentation.predictedEndTranslation,
                minimumDistance: Swift.max(viewerSize.width, viewerSize.height) * Constants.dismissDistanceMultiplier,
                duration: fadeDuration
            )
            dismissalTransition = .toss(toss)
            withAnimation(toss.animation) {
                presentation.dragOffset = toss.endOffset
            }
            withAnimation(.linear(duration: fadeDuration * 0.5).delay(fadeDuration * 0.5)) {
                presentation.imageOpacity = .zero
            }
        }

        withAnimation(.spring) {
            presentation.overlayOpacity = 0
        }
        withAnimation(.linear(duration: fadeDuration)) {
            presentation.backgroundOpacity = .zero
        }
        presentation.transition = dismissalTransition
        presentation.phaseID = UUID()
        presentation.phase = .dismissing
        dismissAction()
    }
}
