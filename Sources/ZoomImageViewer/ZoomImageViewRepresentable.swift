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
    case max(center: CGPoint?)
}

struct ZoomImageViewRepresentable: UIViewRepresentable {
    /// The size of the frame the image is shown in, including safe area insets.
    ///
    /// This is where SwiftUI's layout ends up rather than the size the scroll view is right now. It is handed over once, before SwiftUI starts animating the scroll view's bounds towards it, so ``ZoomImageScrollView`` knows where each frame of that animation is heading.
    let size: CGSize
    /// The safe area insets around the frame, as laid out by SwiftUI.
    ///
    /// Taken from SwiftUI rather than read from the scroll view, because a UIKit view's own `safeAreaInsets` come from the window. A viewer rotated to an orientation the app does not support sits in a window that has not rotated with it, so UIKit reports insets belonging to edges the content no longer meets.
    let safeAreaInsets: UIEdgeInsets
    let isInteractive: Bool
    @Binding var zoomState: ZoomState
    let maximumZoomScale: CGFloat
    
    let uiImage: UIImage
    
    func makeUIView(context: Context) -> ZoomImageScrollView {
        let uiScrollView = ZoomImageScrollView(image: uiImage)
        uiScrollView.delegate = context.coordinator
        
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapGesture(gestureRecognizer:)))
        gesture.numberOfTapsRequired = 2
        uiScrollView.imageView.addGestureRecognizer(gesture)
        
        return uiScrollView
    }
    
    func updateUIView(_ uiScrollView: ZoomImageScrollView, context: Context) {
        /// The coordinator keeps this view to read the current zoom state, so it needs replacing on every update.
        context.coordinator.parent = self
        
        /// A replacement image arrives as a new scroll view rather than a new image in this one, so this only has to skip the redundant assignment on every other update.
        if uiScrollView.imageView.image !== uiImage {
            uiScrollView.imageView.image = uiImage
        }
        
        uiScrollView.setTargetFrame(size: size, safeAreaInsets: safeAreaInsets)
        uiScrollView.requestedMaximumZoomScale = maximumZoomScale
        uiScrollView.isUserInteractionEnabled = isInteractive
        uiScrollView.imageView.isUserInteractionEnabled = isInteractive
        
        switch zoomState {
        case .min:
            if uiScrollView.zoomScale != uiScrollView.minimumZoomScale {
                uiScrollView.setZoomScale(uiScrollView.minimumZoomScale, animated: !UIAccessibility.isReduceMotionEnabled)
            }
        case let .max(center):
            if uiScrollView.zoomScale != uiScrollView.maximumZoomScale {
                // offset to center here
                if let center = center {
                    let rect = CGRect(x: center.x, y: center.y, width: 1, height: 1)
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
        
        init(_ parent: ZoomImageViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handleDoubleTapGesture(gestureRecognizer: UITapGestureRecognizer) -> Void {
            // zoom based on gesture
            switch parent.zoomState {
            case .max(_):
                parent.zoomState = .min
            default:
                if let imageView = gestureRecognizer.view {
                    parent.zoomState = .max(center: gestureRecognizer.location(in: imageView))
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
