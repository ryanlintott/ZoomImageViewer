//
//  ZoomImageViewerHost.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

/// Owns one viewer's presentation state and reconciles it with the external binding.
struct ZoomImageViewerHost<Overlay: View>: View {
    /// Used to resolve the leading and trailing edges VoiceOver scrolls towards before they are handed to UIKit.
    @Environment(\.layoutDirection) private var layoutDirection
    /// With Reduce Motion on, an image with a source fades in and out rather than growing from it and shrinking back.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var uiImage: UIImage?
    let dismissAction: ZoomImageDismissAction
    let overlay: Overlay
    /// The matched geometry effect for the image in the binding, or `nil` when there is no image in it or its image has no source.
    let currentMatchedGeometry: ZoomImageMatchedGeometry?
    
    init(
        uiImage: Binding<UIImage?>,
        dismissAction: ZoomImageDismissAction,
        overlay: Overlay,
        matchedGeometry: ZoomImageMatchedGeometry?,
        reduceMotionAtInsertion: Bool
    ) {
        self._uiImage = uiImage
        self.dismissAction = dismissAction
        self.overlay = overlay
        self.currentMatchedGeometry = matchedGeometry
        self._presentation = State(
            initialValue: ZoomImagePresentationState(
                image: uiImage.wrappedValue,
                openingStyle: Self.openingStyle(
                    matchedGeometry: matchedGeometry,
                    reduceMotion: reduceMotionAtInsertion
                ),
                availableMatchedGeometry: matchedGeometry
            )
        )
    }

    /// The one owner of presentation lifetime, interaction, chrome and animated appearance targets.
    @State private var presentation: ZoomImagePresentationState
    /// How far the viewer is turned from the window by a container like `AutoRotatingView`, undone as a matched image lands on its source.
    @State private var contentRotation = ContentRotation()
    
    /// How long the viewer takes to fade in or out, and a thrown image takes to leave the screen.
    let fadeDuration: TimeInterval = 0.4
    /// How long the overlay, status bar and home indicator take to hide or show.
    let chromeDuration: TimeInterval = 0.25
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    /// How far a dismissed image travels at least, as a multiple of the viewer's longest side. An image inside the frame needs at most the frame's diagonal, about 1.41 times its longest side, to leave in any direction, so this leaves room for how far it had already been dragged.
    let dismissDistanceMultiplier: CGFloat = 2
    /// How wide the background is, as a multiple of the frame's diagonal.
    ///
    /// The diagonal on its own is exactly enough to cover the frame at any angle, as the frame's corners land on the background square's inscribed circle. Exactly enough leaves nothing for rounding, so the corners touch the edge rather than clearing it. This clears them by a twentieth of the diagonal, around 46pt on a 393×852 frame, and is still a fraction of the frame-sized padding it replaced.
    let backgroundDiagonalMultiplier: CGFloat = 1.1
    
    func canvas(uiImage: UIImage, viewerSize: CGSize) -> ZoomImageCanvas {
        ZoomImageCanvas(
            uiImage: uiImage,
            viewerSize: viewerSize,
            isShowingImage: isShowingImage,
            isInteractive: presentation.isInteractive,
            isShowingOverlay: presentation.isShowingOverlay,
            accessibilityScrollRequest: presentation.accessibilityScrollRequest,
            presentationOffset: presentationOffset,
            canvasID: presentation.canvasID,
            matchedGeometry: matchedGeometry,
            imageTransition: imageTransition,
            zoomState: $presentation.zoomState,
            isZoomedIn: $presentation.isZoomedIn.animation(.easeInOut(duration: chromeDuration)),
            overlayIsShowing: $presentation.isShowingOverlay.animation(.easeInOut(duration: chromeDuration)),
            onToggleOverlay: toggleOverlay,
            onAccessibilityZoomIn: { center in
                if #available(iOS 16, *) {
                    accessibilityZoom(.zoomIn, center: center)
                }
            },
            onAccessibilityZoomOut: {
                if #available(iOS 16, *) {
                    accessibilityZoom(.zoomOut, center: .zero)
                }
            },
            onAccessibilityScroll: accessibilityScroll,
            onDragChanged: { value in
                recordDragValue(value)
                onDrag(translation: value.translation)
            },
            onDragFinal: recordDragValue,
            onDragEnded: onDragEnded
        )
    }

    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                /// The image fills the whole frame, safe area included, like in Photos.
                let viewerSize = proxy.sizeIncludingSafeAreaInsets
                /// The side of the square painted behind the image, which covers the frame whichever way a container has turned it.
                let backgroundSide = viewerSize.magnitude * backgroundDiagonalMultiplier

                /// Always in the hierarchy, so the rotation of a viewer showing nothing is known by the time an image appears.
                ContentRotationReader(rotation: $contentRotation)
                    .ignoresSafeArea()

                if let uiImage = presentedImage {
                    ZoomImageViewerScreen(
                        canvas: canvas(uiImage: uiImage, viewerSize: viewerSize),
                        overlay: overlay,
                        backgroundSide: backgroundSide,
                        backgroundOpacity: presentation.appearance.backgroundOpacity,
                        imageOpacity: presentation.appearance.imageOpacity,
                        overlayOpacity: presentation.appearance.overlayOpacity,
                        isShowingOverlay: presentation.isShowingOverlay,
                        isShowingSystemOverlay: isShowingSystemOverlay,
                        usesMatchedGeometry: matchedGeometry != nil,
                        dismissAction: dismissAction,
                        onDismiss: dismiss,
                        onAppear: onAppear,
                        onDisappear: onDisappear
                    )
                }
            }
            .onChange(of: request) { request in
                apply(request)
            }
        )
        /// Removes a faded out image once it can no longer be seen. Cancelled when a new image is shown, or when the viewer leaves the view hierarchy.
        .task(id: presentation.dismissalID) {
            guard let dismissal = presentation.dismissal else { return }
            /// A matched image is still settling on its source after the rest of the viewer has faded out, and is only taken away once it has.
            let wait: TimeInterval
            if case .matched = dismissal.style {
                wait = ZoomImageMatchedGeometry.settlingDuration
            } else {
                wait = fadeDuration
            }
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            _ = presentation.finishDismissal(id: dismissal.id)
        }
        /// Stops the opening plan from governing later source and Reduce Motion changes. The session token prevents an obsolete completion from changing a replacement.
        .task(id: presentation.presentationID) {
            guard let session = presentation.session, session.isOpening else { return }
            let wait: TimeInterval
            if case .matched = session.openingStyle {
                wait = ZoomImageMatchedGeometry.settlingDuration
            } else {
                wait = fadeDuration
            }
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            _ = presentation.finishOpening(id: session.id)
        }
        /// Everything in the viewer resolves against the dark colour scheme, whatever the app's appearance: the background, which is `systemBackground`, and the overlay, so a caption's `.secondary` or a button's tint is the one for a dark background rather than the app's. Forced rather than read from the environment, so the background and the views over it can never disagree.
        .colorScheme(.dark)
    }

    /// The values that must be reconciled together after an external presentation change.
    ///
    /// The one-parameter `onChange` closure sees the view from before its new value. Reading
    /// `currentMatchedGeometry` from that closure would therefore combine a new image with the
    /// source match from the preceding render. The request carries the new values into the closure.
    var request: ZoomImagePresentationRequest {
        ZoomImagePresentationRequest(
            image: uiImage,
            matchedGeometry: currentMatchedGeometry,
            reduceMotion: reduceMotion
        )
    }

    /// The matched geometry effect the image on screen grows from and shrinks back to, or `nil` to fade the image in and out.
    ///
    /// Clearing an item clears its identifier in the same transaction, while the image still has to shrink back into the source it came from. So once the binding is cleared, the matched geometry of the last image in it is used instead. A viewer with a namespace always has one while an image is on screen, as its binding only holds an image while it holds an item.
    ///
    /// Reduce Motion is read when each transition begins. A running dismissal retains the plan it started with.
    ///
    /// While the binding is empty, a matched dismissal reads the geometry retained in its immutable plan.
    var matchedGeometry: ZoomImageMatchedGeometry? {
        if uiImage != nil {
            if let session = presentation.session, session.isOpening {
                guard case .matched(let matchedGeometry) = session.openingStyle else { return nil }
                return matchedGeometry
            }
            guard !reduceMotion else { return nil }
            return currentMatchedGeometry
        }

        if let dismissal = presentation.dismissal {
            guard case .matched(let matchedGeometry) = dismissal.style else { return nil }
            return matchedGeometry
        }

        guard !reduceMotion else { return nil }
        return presentation.availableMatchedGeometry
    }

    /// The source eligible for a dismissal beginning now. Unlike the renderer's opening geometry,
    /// this samples the latest source and Reduce Motion setting for the next transition.
    var dismissalMatchedGeometry: ZoomImageMatchedGeometry? {
        guard !reduceMotion else { return nil }
        return currentMatchedGeometry ?? presentation.availableMatchedGeometry
    }
    
    /// The image the viewer is built around.
    ///
    /// A viewer without matched geometry shows the session image, which only catches up with the binding once its change has been handled. One with matched geometry falls back on the binding, so the image is added in the same transaction that removes its source and SwiftUI can animate between the two.
    var presentedImage: UIImage? {
        matchedGeometry == nil ? presentation.displayedImage : presentation.displayedImage ?? uiImage
    }
    
    /// Whether the image itself is in the hierarchy.
    ///
    /// A matched image is removed in the same transaction that clears the binding, as its source comes back in that transaction and SwiftUI only shrinks the image back into it when both happen together. The background and overlay stay until they have faded out. An image without a source stays until the rest of the viewer is removed, so it can fade out or be thrown off the screen with the viewer.
    var isShowingImage: Bool {
        matchedGeometry == nil || uiImage != nil
    }

    /// How far the image is dragged from the middle of the frame.
    ///
    /// Dropped as soon as a different image is on its way in while this one is still being removed, as the offset belongs to the image that was dragged away rather than the one replacing it. The image being removed keeps it, so it carries on from where it was dropped rather than snapping back to the middle of the frame.
    var presentationOffset: CGSize {
        if presentation.isDismissing, let uiImage, uiImage !== presentation.displayedImage { return .zero }
        return presentation.drag.offset
    }
    
    /// How far the image moves as it lands on its source, from where a drag left it back to the middle of the frame, where matched geometry takes over.
    var landingMove: CGSize {
        -presentationOffset
    }
    
    /// How the image is added and removed.
    ///
    /// An image with no source has nothing to land on, so it fades in and out with the animation that shows or clears it.
    var imageTransition: AnyTransition {
        guard matchedGeometry != nil else { return .opacity }
        
        return ZoomImageMatchedGeometry.imageTransition(
            undoing: contentRotation,
            moving: landingMove,
            startSpeed: ZoomImageMatchedGeometry.landingStartSpeed(move: landingMove, velocity: presentation.drag.velocity)
        )
    }
    
    
    /// Whether the status bar and home indicator are showing.
    ///
    /// They show along with the overlay only while the image is zoomed out to fit, so showing the controls over a zoomed in image leaves them hidden and the image keeps the whole screen. They come back as soon as the viewer starts fading out rather than once it is gone, so they return along with the content behind it.
    var isShowingSystemOverlay: Bool {
        (presentation.isShowingOverlay && !presentation.isZoomedIn) || presentation.isDismissing
    }
    
    /// Shows or hides the overlay for an assistive technology, the same as a single tap. The status bar and home indicator follow it while the image is zoomed out.
    ///
    /// Ignored while the image is being dragged away, which already fades the overlay out.
    func toggleOverlay() {
        guard presentation.isInteractive else { return }
        withAnimation(.easeInOut(duration: chromeDuration)) {
            presentation.isShowingOverlay.toggle()
        }
    }
    
    /// Dismisses the viewer. Clearing the binding fades it out.
    func dismiss() {
        dismissAction()
    }
    
    /// Fades the viewer out, then removes the image once it can no longer be seen.
    ///
    /// Does nothing while a removal is already under way, such as after dragging the image away, which has its own animation.
    func fadeOut(matchedGeometry: ZoomImageMatchedGeometry?) {
        guard presentation.displayedImage != nil, !presentation.isDismissing else { return }
        let style: ZoomImagePresentationState.Dismissal.Style = matchedGeometry.map { .matched($0) } ?? .fade
        beginRemoval(style: style)
        /// A matched image has already been removed and is shrinking back into its source.
        if matchedGeometry == nil {
            withAnimation(.linear(duration: fadeDuration)) {
                presentation.appearance.imageOpacity = .zero
            }
        }
    }
    
    /// Fades the background and overlay out and starts the removal, so the standard fade out skips this image.
    ///
    /// Shared by every way of closing the viewer. Moving or fading the image itself is left to each of them.
    func beginRemoval(style: ZoomImagePresentationState.Dismissal.Style) {
        withAnimation(.spring) {
            presentation.appearance.overlayOpacity = 0
        }
        withAnimation(.linear(duration: fadeDuration)) {
            presentation.appearance.backgroundOpacity = .zero
        }
        presentation.beginDismissal(style: style)
    }
    
    /// Shows `newImage`, fading it in only when there is nothing on screen to replace, or fades the viewer out when there is no image.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ request: ZoomImagePresentationRequest) {
        guard let newImage = request.image else {
            /// Clearing the item also clears the request's source identifier. The source available
            /// immediately before that change was recorded while the item still existed.
            let dismissalMatchedGeometry = request.reduceMotion ? nil : presentation.availableMatchedGeometry
            fadeOut(matchedGeometry: dismissalMatchedGeometry)
            /// The outgoing image was removed with the old identity in the binding transaction. A new identity now prevents an image presented before cleanup from reviving that removed canvas partway through its landing.
            presentation.prepareCanvasAfterMatchedRemoval()
            return
        }

        let present = {
            presentation.present(
                newImage,
                openingStyle: Self.openingStyle(
                    matchedGeometry: request.matchedGeometry,
                    reduceMotion: request.reduceMotion
                ),
                availableMatchedGeometry: request.matchedGeometry
            )
        }

        let change: ZoomImagePresentationState.PresentationChange
        if presentation.displayedImage == nil || presentation.displayedImage === newImage {
            /// A first matched presentation must stay in the animated transaction that inserted the
            /// destination and removed its source. Disabling animations here interrupts that match
            /// with a second state update and makes the destination snap into its final frame.
            change = present()
        } else {
            /// A replacement keeps the original immediate-swap behaviour even when its caller used
            /// `withAnimation`.
            change = withoutAnimation(present)
        }

        switch change {
        case .unchanged, .inserted:
            return
        case .resumed:
            onAppear()
        case .replaced:
            announceReplacement(newImage)
        case .replacedDuringDismissal:
            onAppear()
            announceReplacement(newImage)
        }
    }

    static func openingStyle(
        matchedGeometry: ZoomImageMatchedGeometry?,
        reduceMotion: Bool
    ) -> ZoomImagePresentationState.Session.OpeningStyle {
        guard let matchedGeometry, !reduceMotion else { return .fade }
        return .matched(matchedGeometry)
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
        presentation.accessibilityScrollRequest = AccessibilityScrollRequest(edge: UIRectEdge(accessibilityScrollEdge: edge, layoutDirection: layoutDirection))
    }
    
    /// Reads out the description of an image that replaced the one on screen, as VoiceOver focus stays wherever it was, often on the control that swapped the image.
    ///
    /// Queued rather than interrupting, so the control's own response is not cut off. Images without an accessibility label are not announced.
    func announceReplacement(_ newImage: UIImage) {
        guard let label = newImage.accessibilityLabel, !label.isEmpty else { return }
        let announcement = NSAttributedString(string: label, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Puts an image on screen unmoved, zoomed out and interactive, never inheriting the state of the image before it.
    func resetPresentation() {
        presentation.resetInteraction()
    }
    
    func onAppear() {
        resetPresentation()
        /// An image without a source has nothing to grow from, so it fades in.
        if matchedGeometry == nil {
            presentation.appearance.backgroundOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                presentation.appearance.imageOpacity = 1
            }
        } else {
            /// The image grows from its source instead of fading in, so only the background behind it fades.
            presentation.appearance.imageOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                presentation.appearance.backgroundOpacity = 1
            }
        }
        withAnimation(.easeIn(duration: fadeDuration).delay(fadeDuration)) {
            presentation.appearance.overlayOpacity = 1
        }
    }
    
    func onDisappear() {
        presentation.appearance = .init()
    }

    /// Keeps where the drag is heading and how fast, for when it ends.
    func recordDragValue(_ value: DragGesture.Value) {
        if #available(iOS 17, *) {
            presentation.drag.velocity = value.velocity
        }
        presentation.drag.predictedEndTranslation = value.predictedEndTranslation
    }
    
    func onDrag(translation: CGSize) {
        /// Hides the overlay as the drag starts, so nothing moves around over the image while it is dragged. It only comes back if the image is put back.
        if presentation.isInteractive {
            withAnimation(.easeInOut(duration: chromeDuration)) {
                presentation.appearance.overlayOpacity = 0
            }
        }
        presentation.isInteractive = false
        presentation.drag.offset = translation
        presentation.appearance.backgroundOpacity = 1 - Double(translation.magnitude / dismissThreshold) * (1 - opacityAtDismissThreshold)
    }
    
    /// Dismisses the image when the drag was heading far enough away, or puts it back otherwise.
    ///
    /// Called when the drag's gesture state resets rather than from the gesture's `onEnded`, so a drag that is cancelled is put back too.
    ///
    /// Reads the drag's predicted end and velocity from state, which is current even from the `onChange(of:perform:)` closure that calls this.
    /// - Parameter frameSize: The size of the viewer's frame including its safe area, which a dismissed image leaves.
    func onDragEnded(frameSize: CGSize) {
        guard presentation.drag.predictedEndTranslation.magnitude > dismissThreshold else {
            presentation.isInteractive = true
            withAnimation(.easeOut) {
                presentation.appearance.backgroundOpacity = 1
                presentation.appearance.overlayOpacity = 1
                presentation.drag = .init()
            }
            return
        }

        let dismissalStyle: ZoomImagePresentationState.Dismissal.Style
        /// A matched image shrinks back into its source from wherever it was dragged to, rather than being thrown off screen, with the viewer's own landing animation. Its offset is left where the drag put it and taken back to nothing by the transition, which carries on at the speed the drag was let go at. A change to the offset here would be applied to the removed image at once rather than animated, dragging it back to the middle of the frame before it sets off.
        if let matchedGeometry = dismissalMatchedGeometry {
            dismissalStyle = .matched(matchedGeometry)
        } else {
            /// Lasts as long as the background's fade, so the image is off the screen by the time the background is gone.
            let toss = DismissToss(offset: presentation.drag.offset, velocity: presentation.drag.velocity, predictedEndTranslation: presentation.drag.predictedEndTranslation, minimumDistance: Swift.max(frameSize.width, frameSize.height) * dismissDistanceMultiplier, duration: fadeDuration)
            dismissalStyle = .toss(toss)
            withAnimation(toss.animation) {
                presentation.drag.offset = toss.endOffset
            }
            withAnimation(.linear(duration: fadeDuration * 0.5).delay(fadeDuration * 0.5)) {
                presentation.appearance.imageOpacity = .zero
            }
        }
        /// Started before clearing the binding, so the standard fade out skips this image.
        beginRemoval(style: dismissalStyle)
        dismissAction()
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var uiImage: UIImage? = UIImage(systemName: "gear")

    Color.clear
        .zoomImageViewer(uiImage: $uiImage)
}
