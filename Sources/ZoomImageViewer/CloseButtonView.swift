//
//  File.swift
//  
//
//  Created by Ryan Lintott on 2021-01-13.
//

#if os(iOS)
import SwiftUI

public struct CloseButton: View {
    let image: Image
    let size: CGSize
    let color: Color
    let blendMode: BlendMode
    let paddingAmount: CGFloat
    
    init(image: Image = defaultImage, size: CGSize = defaultSize, color: Color = defaultColor, blendmode: BlendMode = defaultBlendMode, paddingAmount: CGFloat = defaultPaddingAmount) {
        self.image = image
        self.size = size
        self.color = color
        self.blendMode = blendmode
        self.paddingAmount = paddingAmount
    }
    
    public var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .foregroundColor(color)
            .blendMode(blendMode)
            .padding(paddingAmount)
            .contentShape(Rectangle())
    }
    
    static let defaultImage = Image(systemName: "xmark")
    static let defaultSize = CGSize(width: 20, height: 20)
    static let defaultColor = Color.white
    static let defaultBlendMode = BlendMode.difference
    static let defaultPaddingAmount: CGFloat = 10
}
#endif
