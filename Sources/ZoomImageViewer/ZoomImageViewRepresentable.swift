//
//  ZoomImageViewRepresentable.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-20.
//

import SwiftUI

enum ZoomState: Comparable, Sendable {
    case min, partial
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
    let proxy: GeometryProxy
    let isInteractive: Bool
    @Binding var zoomState: ZoomState
    let maximumZoomScale: CGFloat
    
    let uiImage: UIImage
    
    var size: CGSize {
        proxy.size + CGSize(width: proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing, height: proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
    }
    
    var intrinsicContentSize: CGSize {
        uiImage.size
    }
    
    var minimumZoomScale: CGFloat {
        intrinsicContentSize.aspectRatio > size.aspectRatio ? size.width / intrinsicContentSize.width : size.height / intrinsicContentSize.height
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
        if let imageView = uiScrollView.subviews.first as? UIImageView {
            imageView.image = uiImage
        }
        
        uiScrollView.isUserInteractionEnabled = isInteractive
        uiScrollView.subviews.first?.isUserInteractionEnabled = isInteractive
        
        if uiScrollView.minimumZoomScale != minimumZoomScale {
            uiScrollView.minimumZoomScale = minimumZoomScale
            uiScrollView.maximumZoomScale = maximumZoomScale

            switch zoomState {
            case .min:
                uiScrollView.setZoomScale(minimumZoomScale, animated: false)
            case .max:
                uiScrollView.setZoomScale(maximumZoomScale, animated: false)
            default:
                break
            }

            let contentOffset = uiScrollView.contentOffset - CGPoint(cgSize: (size - uiScrollView.visibleSize) / 2)
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
        let offset = (size - uiScrollView.contentSize) / 2.0
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
