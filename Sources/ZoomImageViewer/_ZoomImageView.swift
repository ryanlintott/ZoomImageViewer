//
//  _ZoomImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

struct _ZoomImageView<Overlay: View>: View {
    /// Used to resolve the leading and trailing safe area insets before they are handed to UIKit.
    @Environment(\.layoutDirection) private var layoutDirection
    
    @Binding var uiImage: UIImage?
    let overlay: Overlay
    
    init(uiImage: Binding<UIImage?>, overlay: Overlay) {
        self._uiImage = uiImage
        self.overlay = overlay
        self._displayedImage = State(initialValue: uiImage.wrappedValue)
    }
    
    /// The image on screen, which lags ``uiImage`` so a dismissed image can fade out before it is removed.
    @State private var displayedImage: UIImage?
    
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
    
    @GestureState private var isDragging = false
    
    let animationSpeed = 0.4
    /// How long the overlay, status bar and home indicator take to hide or show.
    let chromeAnimationSpeed = 0.25
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    /// How far a dismissed image travels at least, as a multiple of the viewer's longest side. An image inside the frame needs at most the frame's diagonal, about 1.41 times its longest side, to leave in any direction, so this leaves room for how far it had already been dragged.
    let dismissDistanceMultiplier: CGFloat = 2
    
    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                let viewerFrame = SafeAreaFrame(proxy, layoutDirection: layoutDirection)
                
                if let uiImage = displayedImage {
                    ZStack {
                        ZoomImageViewRepresentable(frame: viewerFrame, isInteractive: isInteractive, zoomState: $zoomState, isZoomedIn: $isZoomedIn.animation(.easeInOut(duration: chromeAnimationSpeed)), isShowingOverlay: $isShowingOverlay.animation(.easeInOut(duration: chromeAnimationSpeed)), accessibilityScrollRequest: accessibilityScrollRequest, maximumZoomScale: 2.0, uiImage: uiImage)
                            /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out. Only this view is rebuilt, leaving the opacities and gestures around it untouched so a replacement appears without any transition.
                            .id(ObjectIdentifier(uiImage))
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
                                    accessibilityZoom(action.direction, center: viewerFrame.safeCentre)
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
                        .offset(offset)
                        /// Attached to the whole frame rather than just the image, so a zoomed out image can be pinched or dragged away from the empty space around it as well.
                        .simultaneousGesture(dragImageGesture, isEnabled: zoomState == ZoomState.min)
                        .onChange(of: isDragging) { newValue in
                            if !newValue {
                                onDragEnded(predictedEndTranslation: predictedEndTranslation, velocity: velocity, frameSize: viewerFrame.size)
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
                }
            }
            .onChange(of: uiImage) { uiImage in
                apply(uiImage)
            }
        )
        /// Removes a faded out image once it can no longer be seen. Cancelled when a new image is shown, or when the viewer leaves the view hierarchy.
        .task(id: removalID) {
            guard removalID != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(animationSpeed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            removalID = nil
            displayedImage = nil
        }
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
        withAnimation(.easeInOut(duration: chromeAnimationSpeed)) {
            isShowingOverlay.toggle()
        }
    }
    
    /// Closes the viewer. Clearing the binding fades it out.
    func close() {
        uiImage = nil
    }
    
    /// Fades the viewer out, then removes the image once it can no longer be seen.
    ///
    /// Does nothing while a removal is already under way, such as after dragging the image away, which has its own animation.
    func fadeOut() {
        guard displayedImage != nil, removalID == nil else { return }
        withAnimation(.spring) {
            overlayOpacity = 0
        }
        withAnimation(.linear(duration: animationSpeed)) {
            backgroundOpacity = .zero
            imageOpacity = .zero
        }
        removalID = UUID()
    }
    
    /// Shows `newImage`, fading it in only when there is nothing on screen to replace, or fades the viewer out when there is no image.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ newImage: UIImage?) {
        guard let newImage else {
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
    /// - Parameter center: The middle of the viewer's safe area, measured from the top left corner of its frame.
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
        zoomState = .min
        /// A replacement image gets a new scroll view, which starts zoomed out without reporting a zoom, so the overlay is shown for it here.
        isZoomedIn = false
        isShowingOverlay = true
        accessibilityScrollRequest = nil
        isInteractive = true
    }
    
    func onAppear() {
        resetPresentation()
        backgroundOpacity = 1
        withAnimation(.easeIn(duration: animationSpeed)) {
            imageOpacity = 1
        }
        withAnimation(.easeIn(duration: animationSpeed).delay(animationSpeed)) {
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
        if predictedEndTranslation.magnitude > dismissThreshold {
            /// Lasts as long as the background's fade, so the image is off the screen by the time the background is gone.
            let toss = DismissToss(offset: offset, velocity: velocity, predictedEndTranslation: predictedEndTranslation, minimumDistance: Swift.max(frameSize.width, frameSize.height) * dismissDistanceMultiplier, duration: animationSpeed)
            withAnimation(toss.animation) {
                offset = toss.endOffset
                overlayOpacity = 0
            }
            withAnimation(.linear(duration: animationSpeed)) {
                backgroundOpacity = .zero
            }
            withAnimation(.linear(duration: animationSpeed * 0.5).delay(animationSpeed * 0.5)) {
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
            .buttonStyle(ZoomImageCloseButtonStyle())
    }

}
