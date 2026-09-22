//
//  ZoomImageViewRepresentable.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-20.
//

import SwiftUI

enum ZoomState: Equatable, Sendable {
    case min
    case partial
    /// Zoomed in as far as the image goes.
    ///
    /// - Parameter center: The point to zoom in on, measured from the top left corner of the viewer's frame as it appears on screen, or `nil` when there is nowhere to zoom to, such as after a pinch that ended at the maximum. Measured from the frame rather than the image, so SwiftUI can supply one without knowing how the image is zoomed or scrolled.
    case max(center: CGPoint?)
}

struct ZoomImageViewRepresentable: UIViewRepresentable {
    /// When interactive the scroll view can be manipulated.
    let isInteractive: Bool
    /// The image being zoomed
    let uiImage: UIImage
    /// The size of the frame the image is shown in, including the safe area the image ignores, as laid out by SwiftUI.
    ///
    /// This is where SwiftUI's layout ends up rather than the size the scroll view is right now. It is handed over once, before SwiftUI starts animating the scroll view's bounds towards it, so ``ZoomImageScrollView`` knows where each frame of that animation is heading.
    let frameSize: CGSize
    /// Read once, when the scroll view is made.
    let maximumZoomScale: CGFloat
    /// The requested zoom state or the zoom state at rest after any pinch zoom or double-tap animation.
    @Binding var zoomState: ZoomState
    /// Whether the image is zoomed in past the scale that fits it, updated as the zoom scale changes rather than when a zoom ends, so it follows a pinch while it is under way.
    @Binding var isZoomedIn: Bool
    /// Whether the overlay is showing. Zooming in hides it and zooming back out to fit shows it, at the same moment ``isZoomedIn`` changes. A single tap toggles it at any zoom.
    @Binding var isShowingOverlay: Bool
    /// Handled once, the first time the scroll view is updated with it.
    let accessibilityScrollRequest: AccessibilityScrollRequest?
    
    func makeUIView(context: Context) -> ZoomImageScrollView {
        let uiScrollView = ZoomImageScrollView(image: uiImage, maximumZoomScale: maximumZoomScale)
        uiScrollView.delegate = context.coordinator
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapGesture(gestureRecognizer:)))
        doubleTap.numberOfTapsRequired = 2
        uiScrollView.imageView.addGestureRecognizer(doubleTap)
        
        /// On the scroll view rather than the image, so the empty space around a zoomed out image can be tapped too. Waits for a double tap to fail, so the first tap of a double tap doesn't toggle the overlay.
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTapGesture(gestureRecognizer:)))
        singleTap.require(toFail: doubleTap)
        uiScrollView.addGestureRecognizer(singleTap)
        
        return uiScrollView
    }
    
    func updateUIView(_ uiScrollView: ZoomImageScrollView, context: Context) {
        /// The coordinator keeps this view to read the current zoom state, so it needs replacing on every update.
        context.coordinator.parent = self
        
        /// The image is not updated here, as the id of this image is set to the object identifier of the UIImage.
        uiScrollView.setTargetSize(frameSize)
        uiScrollView.isUserInteractionEnabled = isInteractive
        
        /// Only a change of zoom state is applied. A pinch doesn't update the zoom state until it ends, so an update part way through one, like the one hiding the overlay as the image zooms in, would otherwise snap the image back to the scale the pinch started from.
        if zoomState != context.coordinator.appliedZoomState {
            context.coordinator.appliedZoomState = zoomState
            apply(zoomState, to: uiScrollView)
        }
        
        if let accessibilityScrollRequest, accessibilityScrollRequest != context.coordinator.handledScrollRequest {
            context.coordinator.handledScrollRequest = accessibilityScrollRequest
            /// Half the screen rather than a whole one, so each step keeps part of what was on screen before it. An image zoomed to twice its fitted size then takes two steps to cross from one side to the other in the axis it fits.
            let offset = uiScrollView.contentOffset(scrollingTowards: accessibilityScrollRequest.edge, by: uiScrollView.layoutSize / 2)
            
            /// Within half a point, as offsets worked out from zoom scales are rarely whole points.
            if (offset - uiScrollView.contentOffset).magnitude < 0.5 {
                /// The image is already at the edge. `accessibilityScrollAction(_:)` has no way to report that a scroll failed, but VoiceOver treats a repeated scroll status as reaching a border. An empty status plays VoiceOver's border sound without reading anything out. It is only posted here, as a status posted after a scroll that moved the image would repeat too and sound like a border.
                ///
                /// The first swipe against an edge has no earlier status to repeat, so it is silent.
                UIAccessibility.post(notification: .pageScrolled, argument: "")
            } else {
                uiScrollView.setContentOffset(offset, animated: !UIAccessibility.isReduceMotionEnabled)
            }
        }
    }
    
    /// Zooms the scroll view out to fit or in to the maximum, leaving it alone for a partial zoom, which only comes from a pinch that has already happened.
    func apply(_ zoomState: ZoomState, to uiScrollView: ZoomImageScrollView) {
        switch zoomState {
        case .min:
            if uiScrollView.zoomScale != uiScrollView.minimumZoomScale {
                uiScrollView.setZoomScale(uiScrollView.minimumZoomScale, animated: !UIAccessibility.isReduceMotionEnabled)
            }
        case let .max(center):
            if uiScrollView.zoomScale != uiScrollView.maximumZoomScale {
                if let center = center {
                    /// The bounds' origin is the scroll offset, so adding it turns a point on screen into one in the scroll view's content.
                    let imagePoint = uiScrollView.imageView.convert(center + uiScrollView.bounds.origin, from: uiScrollView)
                    let rect = CGRect(x: imagePoint.x, y: imagePoint.y, width: 1, height: 1)
                    uiScrollView.zoom(to: rect, animated: !UIAccessibility.isReduceMotionEnabled)
                }
            }
        case .partial:
            break
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomImageViewRepresentable
        /// The scroll request already applied, so later updates don't scroll again.
        var handledScrollRequest: AccessibilityScrollRequest?
        /// The zoom state last applied to the scroll view, so an update that hasn't changed it leaves the scroll view's zoom alone.
        var appliedZoomState: ZoomState = .min
        /// Whether the image was zoomed in when the zoom scale last changed, kept here rather than read from the binding, which only catches up once the change sent to it has been written.
        private var reportedIsZoomedIn = false
        
        init(_ parent: ZoomImageViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handleSingleTapGesture(gestureRecognizer: UITapGestureRecognizer) {
            parent.isShowingOverlay.toggle()
        }
        
        /// Zooms a fitted image in on the point tapped, and zooms an image zoomed in by any amount back out to fit.
        ///
        /// Decided by the scroll view's zoom scale rather than ``zoomState``, so an image pinched part way in zooms out rather than further in.
        @objc func handleDoubleTapGesture(gestureRecognizer: UITapGestureRecognizer) -> Void {
            guard let scrollView = gestureRecognizer.view?.superview as? ZoomImageScrollView else { return }
            
            if scrollView.isZoomedIn {
                parent.zoomState = .min
            } else {
                parent.zoomState = .max(center: gestureRecognizer.location(in: scrollView) - scrollView.bounds.origin)
            }
        }
        
        /// Hides an overlay shown over a zoomed in image as soon as the image starts moving, like in Photos, so it doesn't cover the part being looked at.
        ///
        /// A zoomed out image is left alone. It can't be panned, and zooming it in hides the overlay once it passes the fitted scale.
        private func hideOverlayIfZoomedIn(_ scrollView: UIScrollView) {
            guard (scrollView as? ZoomImageScrollView)?.isZoomedIn == true, parent.isShowingOverlay else { return }
            parent.isShowingOverlay = false
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            hideOverlayIfZoomedIn(scrollView)
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            hideOverlayIfZoomedIn(scrollView)
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomImageScrollView)?.imageView
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            switch scrollView.zoomScale {
            case scrollView.minimumZoomScale:
                parent.zoomState = .min
            case scrollView.maximumZoomScale:
                parent.zoomState = .max(center: nil)
            default:
                parent.zoomState = .partial
            }
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? ZoomImageScrollView else { return }
            scrollView.updateInset()
            
            /// Only acted on when it changes, as this is called for every step of a pinch and for zooms applied while laying out. An overlay shown or hidden with a tap stays that way until the image next zooms in or back out to fit.
            let isZoomedIn = scrollView.isZoomedIn
            guard isZoomedIn != reportedIsZoomedIn else { return }
            reportedIsZoomedIn = isZoomedIn
            
            /// Zooms started by a double tap or VoiceOver are applied in `updateUIView(_:context:)`, which calls this straight away. SwiftUI ignores state changed while it is updating a view, so the change is written once the update is over.
            let isZoomedInBinding = parent.$isZoomedIn
            let isShowingOverlayBinding = parent.$isShowingOverlay
            Task { @MainActor in
                /// Written together, so the status bar, which depends on both, changes in the same update as the overlay.
                isZoomedInBinding.wrappedValue = isZoomedIn
                isShowingOverlayBinding.wrappedValue = !isZoomedIn
            }
        }
    }
}
