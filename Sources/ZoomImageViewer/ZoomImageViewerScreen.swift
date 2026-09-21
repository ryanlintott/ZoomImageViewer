//
//  ZoomImageViewerScreen.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// Composes a viewer's image canvas, background, chrome and modal accessibility behavior.
struct ZoomImageViewerScreen<Overlay: View>: View {
    let canvas: ZoomImageCanvas
    let overlay: Overlay
    let backgroundSide: CGFloat
    let backgroundOpacity: Double
    let imageOpacity: Double
    let overlayOpacity: Double
    let isShowingOverlay: Bool
    let isShowingSystemOverlay: Bool
    let usesMatchedGeometry: Bool
    let dismissAction: ZoomImageDismissAction
    let onDismiss: () -> Void
    let onAppear: () -> Void
    let onDisappear: () -> Void

    var body: some View {
        canvas
            .ignoresSafeArea()
            .background {
                /// A centred square a little wider than the frame's diagonal, so a rotating wrapper never exposes a corner.
                Color(uiColor: .systemBackground)
                    .frame(width: backgroundSide, height: backgroundSide)
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)
            }
            .opacity(imageOpacity)
            .overlay {
                ZStack {
                    overlay
                }
                .buttonStyle(ZoomImageDefaultButtonStyle())
                .opacity(overlayOpacity)
                .opacity(isShowingOverlay ? 1 : 0)
                .allowsHitTesting(isShowingOverlay)
                .accessibilityHidden(!isShowingOverlay)
                .environment(\.dismissZoomImage, dismissAction)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
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
                onAppear()
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
            .onDisappear {
                onDisappear()
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
            /// Only a matched image participates in the caller's insertion transaction. The rest of the viewer fades itself.
            .transition(usesMatchedGeometry ? .identity : .opacity)
    }
}
