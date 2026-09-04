//
//  ZoomImageViewRepresentable.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-20.
//

import SwiftUI

enum ZoomState: Comparable, Sendable {
    case min
    case partial
    case max(center: CGPoint?)
    
    static func < (lhs: ZoomState, rhs: ZoomState) -> Bool {
        switch lhs {
        case .min:
            return rhs == .min
        case .partial:
            return rhs == .partial
        case let .max(center):
            return rhs == .max(center: center)
        }
    }
}

struct ZoomImageViewRepresentable: UIViewRepresentable {
    /// The size of the frame the image is shown in, including safe area insets.
    ///
    /// Taken as a size rather than a `GeometryProxy` because the coordinator holds on to this view
    /// between updates, and a proxy is only valid during the layout pass it came from.
    let sizeIncludingSafeAreaInsets: CGSize
    let isInteractive: Bool
    @Binding var zoomState: ZoomState
    let maximumZoomScale: CGFloat
    
    let uiImage: UIImage
    
    var intrinsicContentSize: CGSize {
        uiImage.size
    }
    
    var minimumZoomScale: CGFloat {
        intrinsicContentSize.zoomScaleToFit(sizeIncludingSafeAreaInsets)
    }
    
    /// The requested maximum zoom scale, raised when needed so it is never below the minimum.
    ///
    /// An image smaller than the frame needs a minimum zoom scale above 1 just to fit, which can be
    /// larger than the requested maximum. `UIScrollView` behaves unpredictably when its minimum zoom
    /// scale is larger than its maximum, leaving the image too small to fill the frame and refusing
    /// to zoom, so the maximum is raised to allow zooming to twice the fitted size. Images at least
    /// as large as the frame fit at a scale of 1 or less, so they always use the requested maximum.
    var clampedMaximumZoomScale: CGFloat {
        max(maximumZoomScale, minimumZoomScale * 2)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let uiScrollView = UIScrollView()
        uiScrollView.delegate = context.coordinator
        uiScrollView.showsVerticalScrollIndicator = false
        uiScrollView.showsHorizontalScrollIndicator = false
        uiScrollView.clipsToBounds = false
        // lets content move outside safe areas when set to .never
//        uiScrollView.contentInsetAdjustmentBehavior = .never
        
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapGesture(gestureRecognizer:)))
        gesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(gesture)
        imageView.isUserInteractionEnabled = isInteractive
        
        uiScrollView.isUserInteractionEnabled = isInteractive
        uiScrollView.addSubview(imageView)
        return uiScrollView
    }
    
    func updateUIView(_ uiScrollView: UIScrollView, context: Context) {
        /// The coordinator keeps this view to read the current size and zoom state, so it needs
        /// replacing on every update. Without this it lays out against the size from the first
        /// update and mis-centres the image after a rotation or resize.
        context.coordinator.parent = self
        
        /// A replacement image arrives as a new scroll view rather than a new image in this one, so
        /// this only has to skip the redundant assignment on every other update.
        if let imageView = uiScrollView.subviews.first as? UIImageView, imageView.image !== uiImage {
            imageView.image = uiImage
        }
        
        uiScrollView.isUserInteractionEnabled = isInteractive
        uiScrollView.subviews.first?.isUserInteractionEnabled = isInteractive
        
        if uiScrollView.minimumZoomScale != minimumZoomScale {
            /// Set the maximum first so the scroll view never briefly has a minimum above its maximum.
            uiScrollView.maximumZoomScale = clampedMaximumZoomScale
            uiScrollView.minimumZoomScale = minimumZoomScale

            switch zoomState {
            case .min:
                uiScrollView.setZoomScale(minimumZoomScale, animated: false)
            case .max:
                uiScrollView.setZoomScale(clampedMaximumZoomScale, animated: false)
            default:
                break
            }

            let contentOffset = uiScrollView.contentOffset - CGPoint(cgSize: (sizeIncludingSafeAreaInsets - uiScrollView.visibleSize) / 2)
            
            updateInset(uiScrollView)
            
            uiScrollView.contentOffset = contentOffset
        } else {
            switch zoomState {
            case .min:
                if uiScrollView.zoomScale != uiScrollView.minimumZoomScale {
                    uiScrollView.setZoomScale(minimumZoomScale, animated: !UIAccessibility.isReduceMotionEnabled)
                }
            case let .max(center):
                if uiScrollView.zoomScale != uiScrollView.maximumZoomScale {
                    // offset to center here
                    if let center = center {
                        let rect = CGRect(x: center.x, y: center.y, width: 1, height: 1)
                        uiScrollView.zoom(to: rect, animated: !UIAccessibility.isReduceMotionEnabled)
                    }
                }
            default:
                break
            }
        }
    }
    
    func updateInset(_ uiScrollView: UIScrollView) {
        let offset = (sizeIncludingSafeAreaInsets - uiScrollView.contentSize) / 2.0
        uiScrollView.contentInset = UIEdgeInsets(top: max(offset.height, 0), left: max(offset.width, 0), bottom: 0, right: 0)
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
            return scrollView.subviews.first
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
            parent.updateInset(scrollView)
        }
    }
}
