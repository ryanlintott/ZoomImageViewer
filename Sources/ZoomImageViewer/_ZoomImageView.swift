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
    
    init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
    }
    
    @State private var isInteractive: Bool = true
    @State private var zoomState: ZoomState = .min
    @State private var offset: CGSize = .zero
    @State private var predictedOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = .zero
    @State private var imageOpacity: Double = .zero
    
    @GestureState private var isDragging = false
    
    let animationSpeed = 0.4
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    let dismissDistance: CGFloat = 1000
    
    var dragImageGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { value, gestureState, transaction in
                gestureState = true
            }
            .onChanged { value in
                predictedOffset = value.predictedEndTranslation
                onDrag(translation: value.translation)
            }
            .onEnded { value in
                predictedOffset = value.predictedEndTranslation
            }
    }
    
    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                if let uiImage = uiImage {
                    ZoomImageViewRepresentable(proxy: proxy, isInteractive: isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, uiImage: uiImage)
                        .accessibilityIgnoresInvertColors()
                        .offset(offset)
                        /// For testing contentShape
//                        .overlay(
//                            Rectangle()
//                                .scaleToFit(CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom), aspectRatio: uiImage.size.aspectRatio)
//                                .fill(Color.red.opacity(0.5))
//                                .allowsHitTesting(false)
//                        )
                        .contentShape(
                            Rectangle()
                                .scaleToFit(
                                    CGSize(
                                        width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                                        height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                                    ),
                                    aspectRatio: uiImage.size.aspectRatio
                                )
                        )
                        .gesture(zoomState == ZoomState.min ? dragImageGesture : nil)
                        .onChange(of: isDragging, perform: { isDragging in
                            if !isDragging {
                                onDragEnded(predictedEndTranslation: predictedOffset)
                            }
                        })
                        .ignoresSafeArea()
                        .background(
                            Color.black
                                .padding(-.maximum(proxy.size.height, proxy.size.width))
                                .ignoresSafeArea()
                                .opacity(backgroundOpacity)
                        )
                        .overlay(
                            Button {
                                withAnimation(.easeOut(duration: animationSpeed)) {
                                    self.uiImage = nil
                                }
                            } label: {
                                Label("Close", systemImage: "xmark")
                                    .font(.title)
                                    .contentShape(Rectangle())
                            }
                                .buttonStyle(closeButtonStyle)
                                .opacity(backgroundOpacity)
                            , alignment: .topLeading
                        )
                        .opacity(imageOpacity)
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
    
    func onAppear() {
        offset = .zero
        backgroundOpacity = 1
        withAnimation(Animation.easeIn(duration: animationSpeed)) {
            imageOpacity = 1
        }
    }
    
    func onDisappear() {
        backgroundOpacity = .zero
        imageOpacity = .zero
    }
    
    func onDrag(translation: CGSize) {
        isInteractive = false
        offset = translation
        backgroundOpacity = 1 - Double(offset.magnitude / dismissThreshold) * (1 - opacityAtDismissThreshold)
    }
    
    func onDragEnded(predictedEndTranslation: CGSize) {
        if predictedEndTranslation.magnitude > dismissThreshold {
            withAnimation(Animation.linear(duration: animationSpeed)) {
                offset = .max(predictedEndTranslation, predictedEndTranslation.normalized * dismissDistance)
                backgroundOpacity = .zero
            }
            withAnimation(Animation.linear(duration: 0.1).delay(animationSpeed)) {
                uiImage = nil
            }
        } else {
            isInteractive = true
            withAnimation(Animation.easeOut) {
                backgroundOpacity = 1
                offset = .zero
            }
        }
    }
}
