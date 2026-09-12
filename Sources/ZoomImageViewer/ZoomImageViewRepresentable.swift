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
    /// Taken as a size rather than a `GeometryProxy` because the coordinator holds on to this view
    /// between updates, and a proxy is only valid during the layout pass it came from.
    let sizeIncludingSafeAreaInsets: CGSize
    /// The safe area insets around the frame, as laid out by SwiftUI.
    ///
    /// Taken from SwiftUI rather than read from the scroll view, because a UIKit view's own
    /// `safeAreaInsets` come from the window. A viewer rotated to an orientation the app does not
    /// support sits in a window that has not rotated with it, so UIKit reports insets belonging to
    /// edges the content no longer meets.
    let safeAreaInsets: UIEdgeInsets
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
    
    /// Whether `uiScrollView` is carrying zoom scales worked out for a different image or frame.
    ///
    /// Both scales are compared, not just the minimum. A new scroll view starts with a minimum and
    /// a maximum of 1, which an image that fits at a scale of 1 already matches, so going by the
    /// minimum alone left such an image with the default maximum of 1 and unable to zoom at all.
    func zoomScalesAreOutOfDate(for uiScrollView: UIScrollView) -> Bool {
        uiScrollView.minimumZoomScale != minimumZoomScale
        || uiScrollView.maximumZoomScale != clampedMaximumZoomScale
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let uiScrollView = UIScrollView()
        uiScrollView.delegate = context.coordinator
        uiScrollView.showsVerticalScrollIndicator = false
        uiScrollView.showsHorizontalScrollIndicator = false
        uiScrollView.clipsToBounds = false
        /// The safe area is applied by ``updateInset(_:)`` from ``safeAreaInsets`` instead, as the
        /// insets this scroll view would use are the window's and can belong to the wrong edges when used inside `AutoRotatingView` from FrameUp.
        uiScrollView.contentInsetAdjustmentBehavior = .never
        
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
        
        if zoomScalesAreOutOfDate(for: uiScrollView) {
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
    
    /// Centres an image smaller than the frame, and insets one larger than it to the safe area so
    /// every part of it can be scrolled into view.
    ///
    /// This is what `contentInsetAdjustmentBehavior` does on its own, worked out per axis from the
    /// insets SwiftUI laid the frame out with rather than the ones the window would supply.
    func updateInset(_ uiScrollView: UIScrollView) {
        /// Space left over around the image, negative in an axis where the image overflows.
        let free = sizeIncludingSafeAreaInsets - uiScrollView.contentSize
        
        uiScrollView.contentInset = UIEdgeInsets(
            top: free.height > 0 ? free.height / 2 : safeAreaInsets.top,
            left: free.width > 0 ? free.width / 2 : safeAreaInsets.left,
            bottom: free.height > 0 ? 0 : safeAreaInsets.bottom,
            right: free.width > 0 ? 0 : safeAreaInsets.right
        )
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
