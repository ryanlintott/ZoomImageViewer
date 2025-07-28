//
//  TapToFullscreenImageScrollView.swift
//  ZoomImageViewerExample
//
//  Created by Ryan Lintott on 2020-11-17.
//

import FrameUp
import SwiftUI
import ZoomImageViewer

struct TapToFullscreenImageScrollView: View {
    enum CloseButtonOption: String, CaseIterable, Identifiable {
        case `default`
        case defaultZoomImageCloseButtonStyle
        case customZoomImageCloseButtonStyle
        case customButtonStyle
        
        var id: Self {
            self
        }
    }
    
    @State private var isShowingFullScreen = false
    @State private var uiImage: UIImage? = nil
    @State private var closeButtonOption: CloseButtonOption = .default
    
    let smallImage = UIImage(named: "testImage")!
    
    var thumbnailImage: some View {
        Image(uiImage: smallImage)
            .resizable()
            .scaledToFit()
            .accessibilityIgnoresInvertColors()
            .frame(width: 200)
    }
    
    var body: some View {
        GeometryReader { proxy in
            Form {
                VStack(alignment: .leading) {
                    Text("Liquid Glass")
                        .font(.headline)
                    Text("Fallback: Default ZoomImageCloseButtonStyle")
                        .font(.subheadline)
                    
                    Button {
                        closeButtonOption = .default
                        uiImage = smallImage
                    } label: {
                        thumbnailImage
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading) {
                    Text("Default ZoomImageCloseButtonStyle")
                        .font(.headline)
                    
                    Button {
                        closeButtonOption = .defaultZoomImageCloseButtonStyle
                        uiImage = smallImage
                    } label: {
                        thumbnailImage
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading) {
                    Text("Custom ZoomImageCloseButtonStyle")
                        .font(.headline)
                    
                    Button {
                        closeButtonOption = .customZoomImageCloseButtonStyle
                        uiImage = smallImage
                    } label: {
                        thumbnailImage
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading) {
                    Text("Custom Button Style")
                        .font(.headline)
                    
                    Button {
                        closeButtonOption = .customButtonStyle
                        uiImage = smallImage
                    } label: {
                        thumbnailImage
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(
            /// Auto rotating modifier is from FrameUp and is optional if you have an app that only uses portrait but you want to be able to view fullscreen images in landscape as well.
            AutoRotatingView {
                switch closeButtonOption {
                case .default:
                    ZoomImageView(uiImage: $uiImage)
                case .defaultZoomImageCloseButtonStyle:
                    ZoomImageView(uiImage: $uiImage, closeButtonStyle: ZoomImageCloseButtonStyle())
                case .customZoomImageCloseButtonStyle:
                    ZoomImageView(uiImage: $uiImage, closeButtonStyle: ZoomImageCloseButtonStyle(color: .pink, blendmode: .normal, paddingAmount: 0))
                case .customButtonStyle:
                    ZoomImageView(uiImage: $uiImage, closeButtonStyle: MyCustomButtonStyle())
                }
            }
        )
    }
}

struct MyCustomButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Text("Bye")
            .foregroundColor(.white)
            .padding()
            .background(Capsule().fill(.red))
            .rotationEffect(.degrees(configuration.isPressed ? 180 : 0))
            .padding()
    }
}

struct TapToFullscreenImageScrollView_Previews: PreviewProvider {
    static var previews: some View {
        TapToFullscreenImageScrollView()
    }
}
