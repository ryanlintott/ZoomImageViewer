//
//  _ZoomImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

struct _ZoomImageView<Overlay: View>: View {
    /// Used to resolve the leading and trailing edges VoiceOver scrolls towards before they are handed to UIKit.
    @Environment(\.layoutDirection) private var layoutDirection
    
    @Binding var uiImage: UIImage?
    let overlay: Overlay
    /// The matched geometry effect for the image in the binding, or `nil` when there is no image in it or its image has no source.
    let currentMatchedGeometry: ZoomImageMatchedGeometry?
    
    init(uiImage: Binding<UIImage?>, overlay: Overlay, matchedGeometry: ZoomImageMatchedGeometry?) {
        self._uiImage = uiImage
        self.overlay = overlay
        self.currentMatchedGeometry = matchedGeometry
        self._displayedImage = State(initialValue: uiImage.wrappedValue)
        self._displayedMatchedGeometry = State(initialValue: matchedGeometry)
    }
    
    /// The image on screen, which lags ``uiImage`` so a dismissed image can fade out before it is removed.
    @State private var displayedImage: UIImage?
    /// The matched geometry effect of the last image in the binding, kept once the binding is cleared.
    @State private var displayedMatchedGeometry: ZoomImageMatchedGeometry?
    
    @State private var isInteractive: Bool = true
    @State private var zoomState: ZoomState = .min
    /// Whether the image is zoomed in past the scale that fits it.
    @State private var isZoomedIn: Bool = false
    /// Whether the overlay is showing. Like in Photos, zooming in hides it, zooming back out to fit shows it, and a single tap or the accessibility action toggles it.
    @State private var isShowingOverlay: Bool = true
    @State private var offset: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var velocity: CGSize? = nil
    @State private var backgroundOpacity: Double = .zero
    @State private var imageOpacity: Double = .zero
    @State private var overlayOpacity: Double = .zero
    /// The most recent request from an assistive technology to scroll the zoomed image, handled once by the scroll view.
    @State private var accessibilityScrollRequest: AccessibilityScrollRequest? = nil
    /// Identifies the removal of an image that is fading out, or is `nil` when nothing is fading out. Changing it cancels the removal task for the previous value, so showing a new image clears it to cancel the removal.
    @State private var removalID: UUID? = nil
    /// Identifies one presentation of a matched image, from growing out of its source to shrinking back into it. Changed once the image is removed.
    @State private var presentationID = UUID()
    /// How far the viewer is turned from the window by a container like `AutoRotatingView`, undone as a matched image lands on its source.
    @State private var contentRotation = ZoomImageContentRotation()
    
    @GestureState private var isDragging = false
    
    /// How long the viewer takes to fade in or out, and a thrown image takes to leave the screen.
    let fadeDuration: TimeInterval = 0.4
    /// How long the overlay, status bar and home indicator take to hide or show.
    let chromeDuration: TimeInterval = 0.25
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    /// How far a dismissed image travels at least, as a multiple of the viewer's longest side. An image inside the frame needs at most the frame's diagonal, about 1.41 times its longest side, to leave in any direction, so this leaves room for how far it had already been dragged.
    let dismissDistanceMultiplier: CGFloat = 2
    
    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                /// The image fills the whole frame, safe area included, like in Photos.
                let viewerSize = proxy.sizeIncludingSafeAreaInsets
                
                /// Always in the hierarchy, so the rotation of a viewer showing nothing is known by the time an image appears.
                ZoomImageRotationReader(rotation: $contentRotation)
                    .ignoresSafeArea()
                
                if let uiImage = presentedImage {
                    ZStack {
                        /// Keeps the stack filling the frame while a matched image is being removed ahead of the rest of the viewer.
                        Color.clear
                        
                        if isShowingImage {
                            /// Fills the viewer's frame around the image, so the transition's turn has the same anchor point whatever size the image is at.
                            ZStack {
                                ZoomImageViewRepresentable(frameSize: viewerSize, isInteractive: isInteractive, zoomState: $zoomState, isZoomedIn: $isZoomedIn.animation(.easeInOut(duration: chromeDuration)), isShowingOverlay: $isShowingOverlay.animation(.easeInOut(duration: chromeDuration)), accessibilityScrollRequest: accessibilityScrollRequest, maximumZoomScale: 2.0, uiImage: uiImage)
                                    /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out. Only this view is rebuilt, leaving the opacities and gestures around it untouched so a replacement appears without any transition.
                                    .id(ObjectIdentifier(uiImage))
                                    /// Outside the identity above, so a replacement image doesn't grow from a source of its own.
                                    .matchedGeometryEffect(matchedGeometry)
                            }
                            /// Applied here rather than around the whole viewer, so an image dragged away keeps the offset while it is removed. SwiftUI drops an offset applied outside a view it is removing, which drags the image back to the middle of the frame in a single frame before it sets off.
                            .offset(presentationOffset)
                            .id(presentationID)
                            .transition(imageTransition)
                        }
                    }
                    /// Keeps the identity change above inside the stack. Applied to the modifiers below, it would also rebuild the overlay with every replacement image, resetting any state in it.
                        .accessibilityIgnoresInvertColors()
                        /// VoiceOver focuses the image as a single element, so the viewer always has something to focus, even with no close button. It is described by the image's own accessibility label.
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isImage)
                        .accessibilityLabel(Text(uiImage.accessibilityLabel ?? ""))
                        .ifAvailable {
                            if #available(iOS 16, *) {
                                /// Lets assistive technologies such as VoiceOver zoom the image in and out, the same as a double tap.
                                $0.accessibilityZoomAction { action in
                                    accessibilityZoom(action.direction, center: CGPoint(cgSize: viewerSize / 2))
                                }
                            }
                        }
                        /// Lets assistive technologies such as VoiceOver move around a zoomed in image, as the image is a single element with nothing inside it to scroll.
                        .accessibilityScrollAction { edge in
                            accessibilityScroll(towards: edge)
                        }
                        /// Does what a single tap does, which VoiceOver can't pass through to the image. Without it, an overlay hidden by zooming in could only be brought back by zooming out. Named for what it will do, so it reads as a choice rather than a toggle.
                        .accessibilityAction(named: isShowingOverlay
                            ? Text("Hide Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that hides the controls shown over it.")
                            : Text("Show Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that shows the controls over it after they were hidden.")
                        ) {
                            toggleOverlay()
                        }
                        /// Attached to the whole frame rather than just the image, so a zoomed out image can be pinched or dragged away from the empty space around it as well.
                        .simultaneousGesture(dragImageGesture, isEnabled: zoomState == ZoomState.min)
                        .onChange(of: isDragging) { newValue in
                            if !newValue {
                                onDragEnded(predictedEndTranslation: predictedEndTranslation, velocity: velocity, frameSize: viewerSize)
                            }
                        }
                        .ignoresSafeArea()
                        .background(
                            Color.black
                                .padding(-.maximum(proxy.size.height, proxy.size.width))
                                .ignoresSafeArea()
                                .opacity(backgroundOpacity)
                        )
                        .opacity(imageOpacity)
                        .overlay(
                            ZStack {
                                overlay
                            }
                            /// Styles every button in the overlay. A style a button sets for itself is closer to it, so it takes precedence.
                            .buttonStyle(ZoomImageDefaultButtonStyle())
                            .opacity(overlayOpacity)
                            /// Hidden while zoomed in or after a tap, so nothing covers the image. Kept apart from `overlayOpacity` so hiding it never interrupts the overlay fading in or out with the image.
                            .opacity(isShowingOverlay ? 1 : 0)
                            .allowsHitTesting(isShowingOverlay)
                            .accessibilityHidden(!isShowingOverlay)
                            .environment(\.closeZoomImage, ZoomImageCloseAction(uiImage: $uiImage))
                        )
                        /// Keeps VoiceOver inside the viewer while it covers the content behind it, and lets VoiceOver users dismiss the image with the escape gesture.
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) {
                            close()
                        }
                        .background {
                            /// Only in the hierarchy while hiding them, so a viewer showing them leaves the app's own status bar and home indicator settings alone rather than overriding them with its own.
                            if !isShowingSystemOverlay {
                                Color.clear
                                    .statusBarHidden(true)
                                    .ifAvailable {
                                        if #available(iOS 16, *) {
                                            $0.persistentSystemOverlays(.hidden)
                                        }
                                    }
                            }
                        }
                        .onAppear {
                            onAppear()
                            /// Moves VoiceOver focus into the viewer.
                            UIAccessibility.post(notification: .screenChanged, argument: nil)
                        }
                        .onDisappear {
                            onDisappear()
                            /// Moves VoiceOver focus back to the content the viewer covered.
                            UIAccessibility.post(notification: .screenChanged, argument: nil)
                        }
                        /// A matched image is added in the transaction that sets the binding, which is usually animated. Only the image takes part in that animation, so the background and overlay fade in with their own.
                        .transition(matchedGeometry == nil ? .opacity : .identity)
                }
            }
            .onChange(of: uiImage) { uiImage in
                apply(uiImage)
            }
            .onChange(of: currentMatchedGeometry) { matchedGeometry in
                /// Read from the new value, as this closure sees the view from before the change. Left alone when it is cleared along with the binding.
                if let matchedGeometry {
                    displayedMatchedGeometry = matchedGeometry
                }
            }
        )
        /// Removes a faded out image once it can no longer be seen. Cancelled when a new image is shown, or when the viewer leaves the view hierarchy.
        .task(id: removalID) {
            guard removalID != nil else { return }
            /// A matched image is still settling on its source after the rest of the viewer has faded out, and is only taken away once it has.
            let wait = matchedGeometry == nil ? fadeDuration : ZoomImageMatchedGeometry.settlingDuration
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            removalID = nil
            displayedImage = nil
            /// The next image starts from a clean slate. State left behind by the image just removed, like the offset it was thrown away with, would otherwise still be in place as the next one is added, and a matched image would grow from its source offset by it.
            resetPresentation()
        }
    }
    
    /// The matched geometry effect the image on screen grows from and shrinks back to, or `nil` to fade the image in and out.
    ///
    /// Clearing an item clears its identifier in the same transaction, while the image still has to shrink back into the source it came from. So once the binding is cleared, the matched geometry of the last image in it is used instead. A viewer with a namespace always has one while an image is on screen, as its binding only holds an image while it holds an item.
    ///
    /// Read correctly from closures that see the view from before a change, like `onChange(of:perform:)` and `task(id:)`: the binding and ``displayedMatchedGeometry`` are read as they are now, and ``currentMatchedGeometry`` is only used while the binding holds an image, when it can only be out of date if the item changed in the same update.
    var matchedGeometry: ZoomImageMatchedGeometry? {
        uiImage == nil ? displayedMatchedGeometry : currentMatchedGeometry
    }
    
    /// The image the viewer is built around.
    ///
    /// A viewer without matched geometry shows ``displayedImage``, which only catches up with the binding once its change has been handled. One with matched geometry falls back on the binding, so the image is added in the same transaction that removes its source and SwiftUI can animate between the two.
    var presentedImage: UIImage? {
        matchedGeometry == nil ? displayedImage : displayedImage ?? uiImage
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
        if removalID != nil, let uiImage, uiImage !== displayedImage { return .zero }
        return offset
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
            startSpeed: ZoomImageMatchedGeometry.landingStartSpeed(move: landingMove, velocity: velocity)
        )
    }
    
    
    /// Whether the status bar and home indicator are showing.
    ///
    /// They show along with the overlay only while the image is zoomed out to fit, so showing the controls over a zoomed in image leaves them hidden and the image keeps the whole screen. They come back as soon as the viewer starts fading out rather than once it is gone, so they return along with the content behind it.
    var isShowingSystemOverlay: Bool {
        (isShowingOverlay && !isZoomedIn) || removalID != nil
    }
    
    /// Shows or hides the overlay for an assistive technology, the same as a single tap. The status bar and home indicator follow it while the image is zoomed out.
    ///
    /// Ignored while the image is being dragged away, which already fades the overlay out.
    func toggleOverlay() {
        guard isInteractive else { return }
        withAnimation(.easeInOut(duration: chromeDuration)) {
            isShowingOverlay.toggle()
        }
    }
    
    /// Closes the viewer. Clearing the binding fades it out.
    func close() {
        ZoomImageCloseAction(uiImage: $uiImage)()
    }
    
    /// Fades the viewer out, then removes the image once it can no longer be seen.
    ///
    /// Does nothing while a removal is already under way, such as after dragging the image away, which has its own animation.
    func fadeOut() {
        guard displayedImage != nil, removalID == nil else { return }
        withAnimation(.spring) {
            overlayOpacity = 0
        }
        withAnimation(.linear(duration: fadeDuration)) {
            backgroundOpacity = .zero
            /// A matched image has already been removed and is shrinking back into its source.
            if matchedGeometry == nil {
                imageOpacity = .zero
            }
        }
        removalID = UUID()
    }
    
    /// Shows `newImage`, fading it in only when there is nothing on screen to replace, or fades the viewer out when there is no image.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ newImage: UIImage?) {
        guard let newImage else {
            /// A matched image is removed as the binding is cleared, and may still be shrinking back into its source when the next one is shown. Added again with the same identity, SwiftUI would bring that image back from wherever it has got to rather than growing the next one from its own source. The image has already been removed by now, so the new identity only applies to the next one.
            if matchedGeometry != nil {
                presentationID = UUID()
            }
            fadeOut()
            return
        }
        
        if removalID != nil {
            /// An image shown while the viewer fades out cancels the removal and fades the viewer back in.
            removalID = nil
            if displayedImage !== newImage {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    displayedImage = newImage
                }
            }
            onAppear()
            return
        }
        
        if displayedImage === newImage { return }
        
        if displayedImage == nil {
            /// A first presentation fades in from nothing, started by the image appearing.
            displayedImage = newImage
            return
        }
        
        /// An image already on screen is replaced immediately, with no fade in either direction. Only the state deciding how the image is laid out is reset, leaving the opacities as they are. Animations are disabled so the swap stays immediate even when the caller changed the binding inside `withAnimation`.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedImage = newImage
            resetPresentation()
        }
        
        announceReplacement(newImage)
    }
    
    /// Zooms in or out for an assistive technology.
    ///
    /// Like a double tap, zooming in goes straight to the maximum and zooming out goes straight back to fit, as the maximum is only twice the fitted size. Ignored while the image is being dragged away.
    ///
    /// Zooming in always centres on the middle of the screen rather than where the gesture happened. VoiceOver's gestures can be performed anywhere on screen, so their location says nothing about the part of the image someone wants to see.
    /// - Parameter center: The middle of the viewer, measured from the top left corner of its frame.
    @available(iOS 16, *)
    func accessibilityZoom(_ direction: AccessibilityZoomGestureAction.Direction, center: CGPoint) {
        guard isInteractive else { return }
        
        switch direction {
        case .zoomIn:
            if case .max = zoomState { return }
            zoomState = .max(center: center)
        case .zoomOut:
            zoomState = .min
        }
    }
    
    /// Scrolls a zoomed in image towards `edge` for an assistive technology.
    ///
    /// Ignored while the image is being dragged away. A zoomed out image fits the screen, so the scroll view has nowhere to move it.
    func accessibilityScroll(towards edge: Edge) {
        guard isInteractive else { return }
        accessibilityScrollRequest = AccessibilityScrollRequest(edge: UIRectEdge(accessibilityScrollEdge: edge, layoutDirection: layoutDirection))
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
        offset = .zero
        velocity = nil
        zoomState = .min
        /// A replacement image gets a new scroll view, which starts zoomed out without reporting a zoom, so the overlay is shown for it here.
        isZoomedIn = false
        isShowingOverlay = true
        accessibilityScrollRequest = nil
        isInteractive = true
    }
    
    func onAppear() {
        resetPresentation()
        /// An image without a source has nothing to grow from, so it fades in.
        if matchedGeometry == nil {
            backgroundOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                imageOpacity = 1
            }
        } else {
            /// The image grows from its source instead of fading in, so only the background behind it fades.
            imageOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                backgroundOpacity = 1
            }
        }
        withAnimation(.easeIn(duration: fadeDuration).delay(fadeDuration)) {
            overlayOpacity = 1
        }
    }
    
    func onDisappear() {
        backgroundOpacity = .zero
        imageOpacity = .zero
        overlayOpacity = .zero
    }
    
    var dragImageGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { value, gestureState, transaction in
                gestureState = true
            }
            .onChanged { value in
                if #available(iOS 17, *) {
                    velocity = value.velocity
                }
                predictedEndTranslation = value.predictedEndTranslation
                onDrag(translation: value.translation)
            }
            .onEnded { value in
                if #available(iOS 17, *) {
                    velocity = value.velocity
                }
                predictedEndTranslation = value.predictedEndTranslation
            }
    }
    
    func onDrag(translation: CGSize) {
        isInteractive = false
        offset = translation
        backgroundOpacity = 1 - Double(offset.magnitude / dismissThreshold) * (1 - opacityAtDismissThreshold)
    }
    
    /// Dismisses the image when the drag was heading far enough away, or puts it back otherwise.
    ///
    /// Called when the drag's gesture state resets rather than from the gesture's `onEnded`, so a drag that is cancelled is put back too.
    /// - Parameter frameSize: The size of the viewer's frame including its safe area, which a dismissed image leaves.
    func onDragEnded(predictedEndTranslation: CGSize, velocity: CGSize?, frameSize: CGSize) {
        if predictedEndTranslation.magnitude > dismissThreshold, matchedGeometry != nil {
            withAnimation(.spring) {
                overlayOpacity = 0
            }
            withAnimation(.linear(duration: fadeDuration)) {
                backgroundOpacity = .zero
            }
            /// Starts the removal before clearing the binding, so the standard fade out skips this image.
            removalID = UUID()
            /// The image shrinks back into its source from wherever it was dragged to, rather than being thrown off screen, with the viewer's own landing animation. Its offset is left where the drag put it and taken back to nothing by the transition, which carries on at the speed the drag was let go at. A change to the offset here would be applied to the removed image at once rather than animated, dragging it back to the middle of the frame before it sets off.
            uiImage = nil
        } else if predictedEndTranslation.magnitude > dismissThreshold {
            /// Lasts as long as the background's fade, so the image is off the screen by the time the background is gone.
            let toss = DismissToss(offset: offset, velocity: velocity, predictedEndTranslation: predictedEndTranslation, minimumDistance: Swift.max(frameSize.width, frameSize.height) * dismissDistanceMultiplier, duration: fadeDuration)
            withAnimation(toss.animation) {
                offset = toss.endOffset
                overlayOpacity = 0
            }
            withAnimation(.linear(duration: fadeDuration)) {
                backgroundOpacity = .zero
            }
            withAnimation(.linear(duration: fadeDuration * 0.5).delay(fadeDuration * 0.5)) {
                imageOpacity = .zero
            }
            /// Starts the removal before clearing the binding, so the standard fade out skips this image.
            removalID = UUID()
            uiImage = nil
        } else {
            isInteractive = true
            withAnimation(Animation.easeOut) {
                backgroundOpacity = 1
                offset = .zero
                self.velocity = nil
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var uiImage: UIImage? = UIImage(systemName: "gear")
    
    ZoomImageView(uiImage: $uiImage) {
        ZoomImageDefaultOverlay()
    }

}
