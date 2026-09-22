//
//  ZoomImageCanvas.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// Renders and interacts with the fullscreen image inside a viewer screen.
struct ZoomImageCanvas: View {
    let uiImage: UIImage
    let viewerSize: CGSize
    let isShowingImage: Bool
    let isInteractive: Bool
    let isShowingOverlay: Bool
    let accessibilityScrollRequest: AccessibilityScrollRequest?
    let presentationOffset: CGSize
    let canvasID: UUID
    let matchedGeometry: ZoomImageMatchedGeometry?
    let imageTransition: AnyTransition

    @Binding var zoomState: ZoomState
    @Binding var isZoomedIn: Bool
    @Binding var overlayIsShowing: Bool

    let onToggleOverlay: () -> Void
    let onAccessibilityZoomIn: (CGPoint) -> Void
    let onAccessibilityZoomOut: () -> Void
    let onAccessibilityScroll: (Edge) -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragFinal: (DragGesture.Value) -> Void
    let onDragEnded: (CGSize) -> Void

    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            /// Keeps the stack filling the frame while a matched image is removed ahead of the rest of the viewer.
            Color.clear

            if isShowingImage {
                /// Fills the viewer's frame around the image, so the transition's turn has the same anchor point whatever size the image is at.
                ZStack {
                    ZoomImageViewRepresentable(
                        isInteractive: isInteractive,
                        uiImage: uiImage,
                        frameSize: viewerSize,
                        maximumZoomScale: 2,
                        zoomState: $zoomState,
                        isZoomedIn: $isZoomedIn,
                        isShowingOverlay: $overlayIsShowing,
                        accessibilityScrollRequest: accessibilityScrollRequest
                    )
                    /// A replacement image gets its own scroll view rather than being swapped into the one before it, so it is laid out at its own size and zoomed out.
                    .id(ObjectIdentifier(uiImage))
                    /// Outside the image identity above, so a replacement image doesn't grow from a source of its own.
                    .matchedGeometryEffect(matchedGeometry)
                }
                /// A removed image keeps the offset where it was released. SwiftUI drops offsets outside a view being removed.
                .offset(presentationOffset)
                .id(canvasID)
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
                        onAccessibilityZoomIn(CGPoint(cgSize: viewerSize / 2))
                    case .zoomOut:
                        onAccessibilityZoomOut()
                    }
                }
            }
        }
        .accessibilityScrollAction { edge in
            onAccessibilityScroll(edge)
        }
        .accessibilityAction(named: isShowingOverlay
            ? Text("Hide Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that hides the controls shown over it.")
            : Text("Show Controls", bundle: .module, comment: "Accessibility action on the fullscreen image that shows the controls over it after they were hidden.")
        ) {
            onToggleOverlay()
        }
        .simultaneousGesture(dragImageGesture, isEnabled: zoomState == .min)
        .onChange(of: isDragging) { newValue in
            if !newValue {
                onDragEnded(viewerSize)
            }
        }
    }

    var dragImageGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, gestureState, _ in
                gestureState = true
            }
            .onChanged { value in
                onDragChanged(value)
            }
            /// Records the final velocity, which the last change may not have had.
            .onEnded { value in
                onDragFinal(value)
            }
    }
}
