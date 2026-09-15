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
    /// The frame the image is shown in, including its safe area, as laid out by SwiftUI.
    ///
    /// This is where SwiftUI's layout ends up rather than the size the scroll view is right now. It is handed over once, before SwiftUI starts animating the scroll view's bounds towards it, so ``ZoomImageScrollView`` knows where each frame of that animation is heading.
    ///
    /// The safe area comes from SwiftUI rather than the scroll view, because a UIKit view's own `safeAreaInsets` come from the window which hasn't been rotated by SwiftUI's rotationEffect.
    let frame: SafeAreaFrame
    let isInteractive: Bool
    @Binding var zoomState: ZoomState
    /// Handled once, the first time the scroll view is updated with it.
    let accessibilityScrollRequest: AccessibilityScrollRequest?
    /// Read once, when the scroll view is made.
    let maximumZoomScale: CGFloat
    
    let uiImage: UIImage
    
    func makeUIView(context: Context) -> ZoomImageScrollView {
        let uiScrollView = ZoomImageScrollView(image: uiImage, maximumZoomScale: maximumZoomScale)
        uiScrollView.delegate = context.coordinator
        
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapGesture(gestureRecognizer:)))
        gesture.numberOfTapsRequired = 2
        uiScrollView.imageView.addGestureRecognizer(gesture)
        
        return uiScrollView
    }
    
    func updateUIView(_ uiScrollView: ZoomImageScrollView, context: Context) {
        /// The coordinator keeps this view to read the current zoom state, so it needs replacing on every update.
        context.coordinator.parent = self
        
        /// The image is not updated here, as the id of this image is set to the object identifier of the UIImage.
        uiScrollView.setTargetFrame(frame)
        uiScrollView.isUserInteractionEnabled = isInteractive
        
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
        
        if let accessibilityScrollRequest, accessibilityScrollRequest != context.coordinator.handledScrollRequest {
            context.coordinator.handledScrollRequest = accessibilityScrollRequest
            /// Half the safe area rather than a whole one, so each step keeps part of what was on screen before it. An image zoomed to twice its fitted size then takes two steps to cross from one side to the other in the axis it fits.
            let offset = uiScrollView.contentOffset(scrollingTowards: accessibilityScrollRequest.edge, by: uiScrollView.layoutFrame.safeSize / 2)
            
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomImageViewRepresentable
        /// The scroll request already applied, so later updates don't scroll again.
        var handledScrollRequest: AccessibilityScrollRequest?
        
        init(_ parent: ZoomImageViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handleDoubleTapGesture(gestureRecognizer: UITapGestureRecognizer) -> Void {
            // zoom based on gesture
            switch parent.zoomState {
            case .max(_):
                parent.zoomState = .min
            default:
                if let scrollView = gestureRecognizer.view?.superview {
                    parent.zoomState = .max(center: gestureRecognizer.location(in: scrollView) - scrollView.bounds.origin)
                }
            }
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
            (scrollView as? ZoomImageScrollView)?.updateInset()
        }
    }
}
