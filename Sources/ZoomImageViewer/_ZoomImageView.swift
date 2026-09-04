//
//  _ZoomImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

struct _ZoomImageView<CloseButtonStyle: ButtonStyle>: View {
    @Binding var uiImage: UIImage?
    let closeButtonStyle: CloseButtonStyle
    let closeButtonPosition: Alignment
    
    init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle, closeButtonPosition: Alignment) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
        self.closeButtonPosition = closeButtonPosition
        self._displayedImage = State(initialValue: uiImage.wrappedValue)
    }
    
    /// The image on screen, which lags ``uiImage`` so a replacement can be dismissed before the new
    /// image is presented.
    @State private var displayedImage: UIImage?
    /// Presents the replacement image once the image it replaces has been dismissed.
    @State private var replacementTask: Task<Void, Never>? = nil
    
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
                    ZoomImageViewRepresentable(sizeIncludingSafeAreaInsets: proxy.sizeIncludingSafeAreaInsets, isInteractive: isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, uiImage: uiImage)
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
        withAnimation(.easeOut(duration: animationSpeed)) {
            self.uiImage = nil
        }
    }
    
    /// Shows `newImage`, dismissing whatever is on screen first.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ newImage: UIImage?) {
        guard displayedImage !== newImage else { return }
        
        replacementTask?.cancel()
        
        guard let newImage else {
            /// Leave the image on screen. Dismissing it is animated by whoever cleared the binding,
            /// and this view is removed by its parent once that animation finishes, so clearing it
            /// here would make the image vanish before it could fade out.
            onDisappear()
            return
        }
        
        guard displayedImage != nil else {
            /// Nothing on screen to dismiss first.
            displayedImage = newImage
            onAppear()
            return
        }
        
        /// The viewer presents a single image, so a replacement is shown as a dismissal followed by
        /// a fresh presentation. Going by way of no image at all rebuilds the scroll view, so the
        /// new image is shown at its own size and zoomed out.
        onDisappear()
        displayedImage = nil
        replacementTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(animationSpeed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            displayedImage = newImage
            onAppear()
        }
    }
    
    func onAppear() {
        offset = .zero
        /// A presentation always starts zoomed out and interactive, never inheriting the last one.
        zoomState = .min
        isInteractive = true
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
