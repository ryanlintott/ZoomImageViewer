//
//  RotationMatchingOrientationViewModifier.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-12-31.
//

import SwiftUI

public struct RotationMatchingOrientationViewModifier: ViewModifier {
    @State private var contentOrientation: UIDeviceOrientation? = nil
    @State private var deviceOrientation: UIDeviceOrientation? = nil
        
    let isOn: Bool
    let allowedOrientations: Set<UIDeviceOrientation>
    let animation: Animation?
    
    public init(isOn: Bool? = nil, allowedOrientations: Set<UIDeviceOrientation>? = nil, withAnimation animation: Animation? = nil) {
        self.isOn = isOn ?? true
        self.allowedOrientations = allowedOrientations ?? [.portrait, .landscapeLeft, .landscapeRight]
        self.animation = animation
    }

    var rotation: Angle {
        switch (deviceOrientation, contentOrientation) {
        case (.portrait, .landscapeLeft), (.landscapeLeft, .portraitUpsideDown), (.portraitUpsideDown, .landscapeRight), (.landscapeRight, .portrait):
            return .degrees(90)
        case (.portrait, .landscapeRight), (.landscapeRight, .portraitUpsideDown), (.portraitUpsideDown, .landscapeLeft), (.landscapeLeft, .portrait):
            return .degrees(-90)
        case (.portrait, .portraitUpsideDown), (.landscapeRight, .landscapeLeft), (.portraitUpsideDown, .portrait), (.landscapeLeft, .landscapeRight):
            return .degrees(180)
        default:
            return .zero
        }
    }
    
    var isLandscape: Bool {
        switch (deviceOrientation, contentOrientation) {
        case (.portrait, .landscapeLeft), (.portrait, .landscapeRight), (.portraitUpsideDown, .landscapeLeft), (.portraitUpsideDown, .landscapeRight):
            return true
        default:
            return false
        }
    }
    
    func changeContentOrientation() {
        if allowedOrientations.contains(UIDevice.current.orientation) {
            contentOrientation = UIDevice.current.orientation
        }
        
        if contentOrientation == nil {
            contentOrientation = allowedOrientations.first
        }
    }
    
    func changeDeviceOrientation() {
        let newOrientation = UIDevice.current.orientation

        guard deviceOrientation != newOrientation else {
            if deviceOrientation == nil {
                deviceOrientation = .portrait
            }
            return
        }
        
        if InfoDictionary.supportedOrientations.contains(newOrientation) {
            deviceOrientation = newOrientation
        }
    }
    
    func changeOrientations() {
        withAnimation(animation) {
            changeDeviceOrientation()
            changeContentOrientation()
        }
    }
    
    public func body(content: Content) -> some View {
        if isOn {
            GeometryReader { proxy in
                content
                    .rotationEffect(rotation)
                    .frame(width: isLandscape ? proxy.size.height : proxy.size.width, height: isLandscape ? proxy.size.width : proxy.size.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
//                    .offset(x: (proxy.size.width / 2) - proxy.frame(in: .local).midX, y: (proxy.size.height / 2) - proxy.frame(in: .local).midY)
//                    .frame(width: max(proxy.size.height, proxy.size.width), height: max(proxy.size.height, proxy.size.width))
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                changeOrientations()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                changeOrientations()
            }
            .onAppear {
                changeOrientations()
            }
        } else {
            content
        }
    }
}

extension View {
    public func rotationMatchingOrientation(_ allowedOrientations: Set<UIDeviceOrientation>? = nil, isOn: Bool? = nil, withAnimation animation: Animation? = nil) -> some View {
        self.modifier(RotationMatchingOrientationViewModifier(isOn: self is EmptyView ? false : isOn, allowedOrientations: allowedOrientations, withAnimation: animation))
    }
}
