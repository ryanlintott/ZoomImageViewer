//
//  ZoomImageViewerScreen.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// Composes a viewer's image canvas, background, chrome and modal accessibility behavior.
struct ZoomImageViewerScreen<Overlay: View>: View {
    @Binding var presentation: ZoomImagePresentationState

    let canvas: ZoomImageCanvas
    let overlay: Overlay
    let viewerSize: CGSize
    let dismissAction: ZoomImageDismissAction
    let fadeDuration: TimeInterval

    private enum Constants {
        /// How wide the background is, as a multiple of the frame's diagonal.
        ///
        /// The diagonal on its own is exactly enough to cover the frame at any angle, as the frame's corners land on the background square's inscribed circle. Exactly enough leaves nothing for rounding, so the corners touch the edge rather than clearing it. This clears them by a twentieth of the diagonal, around 46pt on a 393×852 frame, and is still a fraction of the frame-sized padding it replaced.
        static var backgroundDiagonalMultiplier: CGFloat { 1.1 }
    }

    var body: some View {
        canvas
            .ignoresSafeArea()
            .background {
                /// A centred square a little wider than the frame's diagonal, so a rotating wrapper never exposes a corner.
                Color(uiColor: .systemBackground)
                    .frame(width: backgroundSide, height: backgroundSide)
                    .ignoresSafeArea()
                    .opacity(presentation.backgroundOpacity)
            }
            .opacity(presentation.imageOpacity)
            .overlay {
                ZStack {
                    overlay
                }
                .buttonStyle(ZoomImageDefaultButtonStyle())
                .opacity(presentation.overlayOpacity)
                .opacity(presentation.isShowingOverlay ? 1 : 0)
                .allowsHitTesting(presentation.isShowingOverlay && !presentation.isOpening)
                .accessibilityHidden(!presentation.isShowingOverlay)
                .environment(\.dismissZoomImage, dismissAction)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) {
                dismissAction()
            }
            .background {
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
                $presentation.showPresentation(usesMatchedGeometry: usesMatchedGeometry, fadeDuration: fadeDuration)
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
            .onDisappear {
                presentation.resetAppearance()
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
            /// Only a matched image participates in the caller's insertion transaction. The rest of the viewer fades itself.
            .transition(usesMatchedGeometry ? .identity : .opacity)
    }

    /// Whether the image grows from and shrinks back into a source rather than fading.
    ///
    /// Read from the request the canvas was built with rather than the retained transition. A first matched presentation inserts this screen in the render before the host records its opening transition, when the retained transition is still the idle fade.
    var usesMatchedGeometry: Bool {
        presentation.matchedGeometry(for: canvas.request) != nil
    }

    var backgroundSide: CGFloat {
        viewerSize.magnitude * Constants.backgroundDiagonalMultiplier
    }

    /// Whether the status bar and home indicator are showing.
    ///
    /// They show along with the overlay only while the image is zoomed out to fit, so showing the controls over a zoomed in image leaves them hidden and the image keeps the whole screen. They come back as soon as the viewer starts fading out rather than once it is gone, so they return along with the content behind it.
    var isShowingSystemOverlay: Bool {
        (presentation.isShowingOverlay && !presentation.isZoomedIn) || presentation.isDismissing
    }
}
