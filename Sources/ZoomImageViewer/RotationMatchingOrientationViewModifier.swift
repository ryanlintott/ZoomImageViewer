//
//  RotationMatchingOrientationViewModifier.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-12-31.
//

import SwiftUI

#if canImport(UIKit)
public struct RotationMatchingOrientationViewModifier: ViewModifier {
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    
    @State private var orientation: UIDeviceOrientation? = nil
        
    let isOn: Bool
    let allowedOrientations: Set<UIDeviceOrientation>
    let animation: Animation?
    
    public init(isOn: Bool? = nil, allowedOrientations: Set<UIDeviceOrientation>? = nil, withAnimation animation: Animation? = nil) {
        self.isOn = isOn ?? true
        self.allowedOrientations = (allowedOrientations ?? [.landscapeLeft, .landscapeRight]).union([.portrait])
        self.animation = animation
    }
    
    var compatibleSizeClass: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    var rotation: Angle {
        guard isOn && compatibleSizeClass else {
            return .degrees(0)
        }
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
    
    var isLandscape: Bool {
        guard isOn && compatibleSizeClass else {
            return false
        }
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
    
    func changeOrientation() {
        if allowedOrientations.contains(UIDevice.current.orientation) {
            withAnimation(animation) {
                self.orientation = UIDevice.current.orientation
            }
        }
    }
    
    public func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(width: isLandscape ? proxy.size.height : proxy.size.width, height: isLandscape ? proxy.size.width : proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .rotationEffect(rotation)
                
        }
        .onReceive(NotificationCenter.Publisher(center: .default, name: UIDevice.orientationDidChangeNotification)) { _ in
            changeOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            changeOrientation()
        }
        .onAppear(perform: changeOrientation)
    }
}

extension View {
    public func rotationMatchingOrientation(_ allowedOrientations: Set<UIDeviceOrientation>? = nil, isOn: Bool? = nil, withAnimation animation: Animation? = nil) -> some View {
        self
            .modifier(RotationMatchingOrientationViewModifier(isOn: isOn, allowedOrientations: allowedOrientations, withAnimation: animation))
    }
}
#endif
