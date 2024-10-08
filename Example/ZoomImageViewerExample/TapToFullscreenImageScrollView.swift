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
    @State private var isShowingFullScreen = false
    @State private var uiImage: UIImage? = nil
    
    let smallImage = UIImage(named: "testImage")!
    
    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center) {
                Spacer(minLength: 0)
                ScrollView {
                    VStack(alignment: .center) {
                        ForEach(0...20, id: \.self) {
                            Text("Content \($0)")
                        }
                        
                        Image(uiImage: smallImage)
                            .resizable()
                            .scaledToFit()
                            .accessibilityIgnoresInvertColors()
                            .frame(width: 200)
                            .onTapGesture {
                                uiImage = smallImage
                            }
                        
//                        Button {
//                            uiImage = nil
//                            isShowingFullScreen = true
//                        } label: {
//                            Text("Turn off image")
//                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .background(Color.green.opacity(0.5))
        .padding(50)
        .overlay(
            /// Auto rotating modifier is from FrameUp and is optional
            AutoRotatingView {
                ZoomImageView(uiImage: $uiImage)
            }
        )
    }
}

struct TapToFullscreenImageScrollView_Previews: PreviewProvider {
    static var previews: some View {
        TapToFullscreenImageScrollView()
    }
}
