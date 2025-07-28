//
//  _ZoomImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

struct _ZoomImageView<CloseButtonStyle: ButtonStyle>: View {
    @Binding var uiImage: UIImage?
    let closeButtonStyle: CloseButtonStyle?
    
    init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle?) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
    }
    
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
                if let uiImage = uiImage {
                    ZoomImageViewRepresentable(proxy: proxy, isInteractive: isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, uiImage: uiImage)
                        .accessibilityIgnoresInvertColors()
                        .offset(offset)
                        .gesture(zoomState == ZoomState.min ? dragImageGesture : nil)
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
                            .padding(.leading, 19)
                            ,
                            alignment: .topLeading
                        )
                        .onAppear(perform: onAppear)
                        .onDisappear(perform: onDisappear)
                }
            }
            .onChange(of: uiImage) { uiImage in
                /// Included to prevent errors when image is dismissed and clicked quickly again
                uiImage == nil ? onDisappear() : onAppear()
            }
        )
    }
    
    func close() {
        withAnimation(.easeOut(duration: animationSpeed)) {
            self.uiImage = nil
        }
    }
    
    func onAppear() {
        offset = .zero
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
    
    _ZoomImageView(uiImage: $uiImage, closeButtonStyle: ZoomImageCloseButtonStyle())

}
