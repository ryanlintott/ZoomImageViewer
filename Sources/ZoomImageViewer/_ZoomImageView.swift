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
    let overlay: (ZoomImageOverlayContext) -> Overlay
    
    init(uiImage: Binding<UIImage?>, overlay: @escaping (ZoomImageOverlayContext) -> Overlay) {
        self._uiImage = uiImage
        self.overlay = overlay
        self._displayedImage = State(initialValue: uiImage.wrappedValue)
    }
    
    /// The image on screen, which lags ``uiImage`` so a dismissed image can fade out before it is removed.
    @State private var displayedImage: UIImage?
    
    @State private var isInteractive: Bool = true
    @State private var zoomState: ZoomState = .min
    @State private var offset: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var velocity: CGSize? = nil
    @State private var backgroundOpacity: Double = .zero
    @State private var imageOpacity: Double = .zero
    @State private var overlayOpacity: Double = .zero
    
    @GestureState private var isDragging = false
    
    let animationSpeed = 0.4
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
                    ZoomImageViewRepresentable(frame: viewerFrame, isInteractive: isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, uiImage: uiImage)
                        /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out. Only this view is rebuilt, leaving the opacities and gestures around it untouched so a replacement appears without any transition.
                        .id(ObjectIdentifier(uiImage))
                        .accessibilityIgnoresInvertColors()
                        /// VoiceOver focuses the image as a single element, so the viewer always has something to focus, even with no close button. It is described by the image's own accessibility label.
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isImage)
                        .accessibilityLabel(Text(uiImage.accessibilityLabel ?? ""))
                        /// The image comes before the overlay, so it is what VoiceOver reads first when the viewer appears, however the overlay is laid out.
                        .accessibilitySortPriority(1)
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
                                overlay(ZoomImageOverlayContext(close: close))
                            }
                            /// Styles every button in the overlay. A style a button sets for itself is closer to it, so it takes precedence.
                            .buttonStyle(ZoomImageDefaultButtonStyle())
                            .opacity(overlayOpacity)
                        )
                        /// Keeps VoiceOver inside the viewer while it covers the content behind it, and lets VoiceOver users dismiss the image with the escape gesture.
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) {
                            close()
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
    }
    
    func close() {
        withAnimation(.spring) {
            overlayOpacity = 0
        }
        withAnimation(.linear(duration: animationSpeed)) {
            backgroundOpacity = .zero
            imageOpacity = .zero
            uiImage = nil
        }
    }
    
    /// Shows `newImage`, fading it in only when there is nothing on screen to replace.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ newImage: UIImage?) {
        if displayedImage === newImage { return }
        
        guard let newImage else {
            /// Leave the image on screen. Dismissing it is animated by whoever cleared the binding, and this view is removed by its parent once that animation finishes, so clearing it here would make the image vanish before it could fade out.
            onDisappear()
            return
        }
        
        if displayedImage == nil {
            /// A first presentation fades in from nothing.
            displayedImage = newImage
            onAppear()
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
            withAnimation(Animation.linear(duration: 0.1).delay(animationSpeed)) {
                uiImage = nil
            }
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
    
    ZoomImageView(uiImage: $uiImage) { viewer in
        ZoomImageDefaultOverlay(viewer)
            .buttonStyle(ZoomImageCloseButtonStyle())
    }

}
