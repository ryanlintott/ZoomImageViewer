//
//  _ZoomImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

struct _ZoomImageView<CloseButtonStyle: ButtonStyle>: View {
    /// Used to resolve the leading and trailing safe area insets before they are handed to UIKit.
    @Environment(\.layoutDirection) private var layoutDirection
    
    @Binding var uiImage: UIImage?
    let closeButtonStyle: CloseButtonStyle
    let closeButtonPosition: Alignment
    
    init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle, closeButtonPosition: Alignment) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
        self.closeButtonPosition = closeButtonPosition
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
    @State private var closeButtonOpacity: Double = .zero
    
    @GestureState private var isDragging = false
    
    let animationSpeed = 0.4
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    
    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                if let uiImage = displayedImage {
                    ZoomImageViewRepresentable(safeAreaInsets: proxy.safeAreaInsets.uiEdgeInsets(layoutDirection: layoutDirection), isInteractive: isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, uiImage: uiImage)
                        /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out. Only this view is rebuilt, leaving the opacities and gestures around it untouched so a replacement appears without any transition.
                        .id(ObjectIdentifier(uiImage))
                        .accessibilityIgnoresInvertColors()
                        .offset(offset)
                        .simultaneousGesture(dragImageGesture, isEnabled: zoomState == ZoomState.min)
                        /// Debugging overlay
//                        .overlay(
//                            ScaleToFitPadding(
//                                size: uiImage.size
//                            )
//                            .stroke(Color.pink)
//                        )
                        .overlay(
                            ZStack {
                                /// Blocks gestures outside of the image when the image is fully zoomed out
                                if zoomState == ZoomState.min {
                                    Color.clear
                                        .contentShape(ScaleToFitPadding(size: uiImage.size))
                                }
                            }
                        )
                        .onChange(of: isDragging) { newValue in
                            if !newValue {
                                onDragEnded(predictedEndTranslation: predictedEndTranslation, velocity: velocity, frameSize: proxy.size)
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
                            ZoomImageCloseButtonView(
                                closeButtonStyle: closeButtonStyle,
                                opacity: closeButtonOpacity,
                            ) {
                                close()
                            }
                                .padding()
                                .padding(proxy.horizontalContainerCornerInsetsIfAvailable(for: closeButtonPosition))
                            ,
                            alignment: closeButtonPosition
                        )
                        .onAppear(perform: onAppear)
                        .onDisappear(perform: onDisappear)
                }
            }
            .onChange(of: uiImage) { uiImage in
                apply(uiImage)
            }
        )
    }
    
    func close() {
        withAnimation(.spring) {
            closeButtonOpacity = 0
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
            closeButtonOpacity = 1
        }
    }
    
    func onDisappear() {
        backgroundOpacity = .zero
        imageOpacity = .zero
        closeButtonOpacity = .zero
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
                predictedEndTranslation = value.predictedEndTranslation
            }
    }
    
    func onDrag(translation: CGSize) {
        isInteractive = false
        offset = translation
        backgroundOpacity = 1 - Double(offset.magnitude / dismissThreshold) * (1 - opacityAtDismissThreshold)
    }
    
    func onDragEnded(predictedEndTranslation: CGSize, velocity: CGSize?, frameSize: CGSize) {
        if predictedEndTranslation.magnitude > dismissThreshold {
            let dismissDistance = Swift.max(frameSize.width, frameSize.height) * 1.5
            let animation: Animation
            let endOffset: CGSize
            if #available(iOS 17, *) {
                endOffset = predictedEndTranslation.normalized * dismissDistance
                // Transform the velocity size into a double divide it by the dismiss distance to get an initial velocity.
                let initialVelocity = (velocity?.magnitude ?? .zero) / dismissDistance
                animation = .interpolatingSpring(.smooth, initialVelocity: initialVelocity)
            } else {
                animation = .spring
                endOffset = .max(predictedEndTranslation, predictedEndTranslation.normalized * dismissDistance)
            }
            withAnimation(animation) {
                offset = endOffset
                closeButtonOpacity = 0
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
    
    _ZoomImageView(uiImage: $uiImage, closeButtonStyle: ZoomImageCloseButtonStyle(), closeButtonPosition: .topLeading)

}
