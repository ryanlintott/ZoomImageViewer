//
//  ZoomImageViewerHost.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

/// Owns one viewer's presentation state and reconciles it with the external binding.
struct ZoomImageViewerHost<Overlay: View>: View {
    /// With Reduce Motion on, an image with a source fades in and out rather than growing from it and shrinking back.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var uiImage: UIImage?
    let dismissAction: ZoomImageDismissAction
    let overlay: Overlay
    /// The matched geometry effect for the image in the binding, or `nil` when there is no image in it or its image has no source.
    let currentMatchedGeometry: ZoomImageMatchedGeometry?
    
    init(
        uiImage: Binding<UIImage?>,
        dismissAction: ZoomImageDismissAction,
        overlay: Overlay,
        matchedGeometry: ZoomImageMatchedGeometry?,
        reduceMotionAtInsertion: Bool
    ) {
        self._uiImage = uiImage
        self.dismissAction = dismissAction
        self.overlay = overlay
        self.currentMatchedGeometry = matchedGeometry
        self._presentation = State(
            initialValue: ZoomImagePresentationState(
                image: uiImage.wrappedValue,
                openingTransition: .opening(
                    matchedGeometry: matchedGeometry,
                    reduceMotion: reduceMotionAtInsertion
                ),
                availableMatchedGeometry: matchedGeometry
            )
        )
    }

    /// The one owner of presentation lifetime, interaction, chrome and animated appearance targets.
    @State private var presentation: ZoomImagePresentationState
    /// How far the viewer is turned from the window by a container like `AutoRotatingView`, undone as a matched image lands on its source.
    @State private var contentRotation = ContentRotation()
    
    /// How long the viewer takes to fade in or out, and a thrown image takes to leave the screen.
    private let fadeDuration: TimeInterval = 0.4

    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                /// The image fills the whole frame, safe area included, like in Photos.
                let viewerSize = proxy.sizeIncludingSafeAreaInsets
                let currentRequest = request

                /// Always in the hierarchy, so the rotation of a viewer showing nothing is known by the time an image appears.
                ContentRotationReader(rotation: $contentRotation)
                    .ignoresSafeArea()

                if let uiImage = presentation.presentedImage(for: currentRequest) {
                    ZoomImageViewerScreen(
                        presentation: $presentation,
                        canvas: ZoomImageCanvas(
                            presentation: $presentation,
                            request: currentRequest,
                            uiImage: uiImage,
                            viewerSize: viewerSize,
                            contentRotation: contentRotation,
                            dismissAction: dismissAction,
                            fadeDuration: fadeDuration
                        ),
                        overlay: overlay,
                        viewerSize: viewerSize,
                        dismissAction: dismissAction,
                        fadeDuration: fadeDuration
                    )
                }
            }
            .onChange(of: request) { request in
                apply(request)
            }
        )
        /// Completes the active opening or dismissal. A new phase identity cancels obsolete work before it can alter a replacement.
        .task(id: presentation.phaseID) { [phaseID = presentation.phaseID] in
            await completePhase(id: phaseID)
        }
        /// Everything in the viewer resolves against the dark colour scheme, whatever the app's appearance: the background, which is `systemBackground`, and the overlay, so a caption's `.secondary` or a button's tint is the one for a dark background rather than the app's. Forced rather than read from the environment, so the background and the views over it can never disagree.
        .colorScheme(.dark)
    }

    /// The values that must be reconciled together after an external presentation change.
    ///
    /// The one-parameter `onChange` closure sees the view from before its new value. Reading
    /// `currentMatchedGeometry` from that closure would therefore combine a new image with the
    /// source match from the preceding render. The request carries the new values into the closure.
    var request: ZoomImagePresentationRequest {
        ZoomImagePresentationRequest(
            image: uiImage,
            matchedGeometry: currentMatchedGeometry,
            reduceMotion: reduceMotion
        )
    }

    /// Completes the asynchronous phase identified by `id` if it is still current.
    func completePhase(id: UUID) async {
        guard presentation.phaseID == id else { return }

        let phase = presentation.phase
        switch phase {
        case .hidden, .presented:
            return
        case .appearing, .dismissing:
            break
        }

        let wait = presentation.transition.settlingDuration(fadeDuration: fadeDuration)
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        guard !Task.isCancelled,
              presentation.phaseID == id,
              presentation.phase == phase else { return }

        switch phase {
        case .appearing:
            presentation.phase = .presented
        case .dismissing:
            presentation.image = nil
            presentation.availableMatchedGeometry = nil
            presentation.transition = .fade
            presentation.phase = .hidden
            presentation.canvasID = UUID()
            presentation.resetInteraction()
            presentation.resetAppearance()
            presentation.phaseID = UUID()
        case .hidden, .presented:
            break
        }
    }

    /// Shows `newImage`, fading it in only when there is nothing on screen to replace, or fades the viewer out when there is no image.
    ///
    /// Compared by identity, as two images with the same contents are still a replacement.
    @MainActor
    func apply(_ request: ZoomImagePresentationRequest) {
        guard let newImage = request.image else {
            /// Clearing the item also clears the request's source identifier. The source available
            /// immediately before that change was recorded while the item still existed.
            let matchedGeometry = request.reduceMotion ? nil : presentation.availableMatchedGeometry
            if presentation.image != nil,
               presentation.phase != .hidden,
               !presentation.isDismissing {
                let transition = matchedGeometry.map(ZoomImagePresentationTransition.matched) ?? .fade
                withAnimation(.spring) {
                    presentation.overlayOpacity = 0
                }
                withAnimation(.linear(duration: fadeDuration)) {
                    presentation.backgroundOpacity = .zero
                }
                presentation.transition = transition
                presentation.phaseID = UUID()
                presentation.phase = .dismissing
                /// A matched image has already been removed and is shrinking back into its source.
                if matchedGeometry == nil {
                    withAnimation(.linear(duration: fadeDuration)) {
                        presentation.imageOpacity = .zero
                    }
                }
            }
            /// The outgoing image was removed with the old identity in the binding transaction. A new identity now prevents an image presented before cleanup from reviving that removed canvas partway through its landing.
            if presentation.isDismissing, presentation.transition.matchedGeometry != nil {
                presentation.canvasID = UUID()
            }
            return
        }

        let openingTransition = ZoomImagePresentationTransition.opening(
            matchedGeometry: request.matchedGeometry,
            reduceMotion: request.reduceMotion
        )

        if presentation.isDismissing {
            let isReplacement = presentation.image !== newImage
            let resumePresentation = {
                presentation.image = newImage
                presentation.transition = openingTransition
                presentation.availableMatchedGeometry = request.matchedGeometry
                presentation.phaseID = UUID()
                presentation.phase = .appearing
            }
            if isReplacement {
                withoutAnimation(resumePresentation)
            } else {
                resumePresentation()
            }
            restoreAppearance(using: openingTransition)
            if isReplacement {
                announceReplacement(newImage)
            }
            return
        }

        guard presentation.image !== newImage else {
            presentation.availableMatchedGeometry = request.matchedGeometry
            return
        }

        guard presentation.image != nil else {
            /// A first matched presentation must stay in the animated transaction that inserted the
            /// destination and removed its source. Disabling animations here interrupts that match
            /// with a second state update and makes the destination snap into its final frame.
            presentation.image = newImage
            presentation.transition = openingTransition
            presentation.availableMatchedGeometry = request.matchedGeometry
            presentation.phaseID = UUID()
            presentation.phase = .appearing
            return
        }

        /// A replacement keeps the original immediate-swap behaviour even when its caller used
        /// `withAnimation`.
        withoutAnimation {
            presentation.image = newImage
            presentation.transition = openingTransition
            presentation.availableMatchedGeometry = request.matchedGeometry
            presentation.phaseID = UUID()
            presentation.phase = .presented
            presentation.resetInteraction()
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
    
    /// Restores the visible viewer when a presentation interrupts an in-flight dismissal.
    func restoreAppearance(using transition: ZoomImagePresentationTransition) {
        presentation.resetInteraction()
        /// An image without a source has nothing to grow from, so it fades in.
        if transition.matchedGeometry == nil {
            presentation.backgroundOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                presentation.imageOpacity = 1
            }
        } else {
            /// The image grows from its source instead of fading in, so only the background behind it fades.
            presentation.imageOpacity = 1
            withAnimation(.easeIn(duration: fadeDuration)) {
                presentation.backgroundOpacity = 1
            }
        }
        withAnimation(.easeIn(duration: fadeDuration).delay(fadeDuration)) {
            presentation.overlayOpacity = 1
        }
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var uiImage: UIImage? = UIImage(systemName: "gear")

    Color.clear
        .zoomImageViewer(uiImage: $uiImage)
}
