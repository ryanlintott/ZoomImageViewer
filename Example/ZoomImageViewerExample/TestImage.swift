//
//  TestImage.swift
//  ZoomImageViewerExample
//
//  Created by Ryan Lintott on 2026-09-04.
//

import SwiftUI

/// An image generated at a size relative to the frame it will be viewed in.
///
/// The viewer scales an image to fit its frame, so the cases worth testing are the ones where that
/// fit is decided differently: an image smaller than the frame has to be scaled up just to fill it,
/// one that matches the frame exactly fits at a scale of 1, and the rest fit against a single axis
/// while overflowing the other.
enum TestImage: String, CaseIterable, Identifiable {
    /// Smaller than the frame in both dimensions.
    case smaller
    /// Far smaller than the frame, so fitting it is a large scale up.
    case tiny
    /// Taller and narrower than the frame.
    case tallNarrow
    /// Shorter and wider than the frame.
    case shortWide
    /// Exactly the size of the frame.
    case exactFit
    /// Larger than the frame in both dimensions.
    case larger
    /// The bundled image asset at its own fixed size.
    case bundled
    
    var id: Self { self }
    
    var name: String {
        switch self {
        case .smaller: "Smaller"
        case .tiny: "Tiny"
        case .tallNarrow: "Tall and narrow"
        case .shortWide: "Short and wide"
        case .exactFit: "Exact fit"
        case .larger: "Larger"
        case .bundled: "Bundled asset"
        }
    }
    
    var detail: String {
        switch self {
        case .smaller: "Smaller than the frame in both dimensions"
        case .tiny: "Small enough that fitting it is a large scale up"
        case .tallNarrow: "Taller and narrower than the frame"
        case .shortWide: "Shorter and wider than the frame"
        case .exactFit: "The same size as the frame"
        case .larger: "Larger than the frame in both dimensions"
        case .bundled: "A fixed size that ignores the frame"
        }
    }
    
    var color: Color {
        Color(uiColor)
    }
    
    var uiColor: UIColor {
        switch self {
        case .smaller: .systemTeal
        case .tiny: .systemPink
        case .tallNarrow: .systemIndigo
        case .shortWide: .systemOrange
        case .exactFit: .systemGreen
        case .larger: .systemPurple
        case .bundled: .systemGray
        }
    }
    
    /// The bundled image asset.
    ///
    /// `UIImage(named:)` caches, so this is cheap to read repeatedly.
    static var bundledImage: UIImage {
        UIImage(named: "testImage") ?? UIImage()
    }
    
    /// A frame size to fall back on before the viewer has been measured.
    static let placeholderFrameSize = CGSize(width: 390, height: 844)
    
    /// The size this image would be generated at when viewed in a frame of `frameSize`.
    func size(in frameSize: CGSize) -> CGSize {
        let frameSize = frameSize.width > 0 && frameSize.height > 0 ? frameSize : Self.placeholderFrameSize
        
        return switch self {
        case .smaller: CGSize(width: frameSize.width * 0.6, height: frameSize.height * 0.4)
        case .tiny: CGSize(width: 40, height: 30)
        case .tallNarrow: CGSize(width: frameSize.width * 0.35, height: frameSize.height * 1.8)
        case .shortWide: CGSize(width: frameSize.width * 2.2, height: frameSize.height * 0.3)
        case .exactFit: frameSize
        case .larger: CGSize(width: frameSize.width * 1.6, height: frameSize.height * 1.4)
        case .bundled: Self.bundledImage.size
        }
    }
    
    /// An image sized for a frame of `frameSize`.
    ///
    /// Every call returns a new image, even for the same case, so showing one twice in a row is
    /// still a replacement as far as the viewer is concerned.
    func image(in frameSize: CGSize) -> UIImage {
        guard self != .bundled else { return Self.bundledImage }
        return Self.render(size: size(in: frameSize), title: name, color: uiColor)
    }
    
    /// Draws an image that makes its own edges, centre and corners easy to pick out while zooming.
    private static func render(size: CGSize, title: String, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        /// A scale of 1 means points and pixels match, so the image reports exactly `size`.
        format.scale = 1
        format.opaque = true
        
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            let shortestSide = min(size.width, size.height)
            
            color.setFill()
            cgContext.fill(bounds)
            
            /// Diagonals cross at the centre, so it is obvious where a zoom is centred.
            let lineWidth = max(1, shortestSide * 0.015)
            UIColor.white.withAlphaComponent(0.6).setStroke()
            cgContext.setLineWidth(lineWidth)
            cgContext.move(to: .zero)
            cgContext.addLine(to: CGPoint(x: size.width, y: size.height))
            cgContext.move(to: CGPoint(x: size.width, y: 0))
            cgContext.addLine(to: CGPoint(x: 0, y: size.height))
            cgContext.strokePath()
            
            /// Corner markers show when a pan has reached the end of the image.
            let markerSide = shortestSide * 0.12
            UIColor.black.withAlphaComponent(0.4).setFill()
            for x in [CGFloat.zero, size.width - markerSide] {
                for y in [CGFloat.zero, size.height - markerSide] {
                    cgContext.fill(CGRect(x: x, y: y, width: markerSide, height: markerSide))
                }
            }
            
            /// A border makes the edges of the image visible against a black background.
            UIColor.white.setStroke()
            cgContext.setLineWidth(lineWidth * 2)
            cgContext.stroke(bounds.insetBy(dx: lineWidth, dy: lineWidth))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let label = NSAttributedString(
                string: "\(title)\n\(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt",
                attributes: [
                    .font: UIFont.systemFont(ofSize: min(max(shortestSide * 0.09, 8), 48), weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
            )
            let labelSize = label.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil).size
            
            /// Anything smaller than its own label is left blank rather than drawn over.
            if labelSize.width <= size.width && labelSize.height <= size.height {
                label.draw(
                    in: CGRect(
                        x: (size.width - labelSize.width) / 2,
                        y: (size.height - labelSize.height) / 2,
                        width: labelSize.width,
                        height: labelSize.height
                    )
                )
            }
        }
    }
}

/// A scale drawing of a test image inside the frame it will be viewed in.
struct TestImageDiagram: View {
    let testImage: TestImage
    let frameSize: CGSize
    
    var maxSide: CGFloat = 44
    
    var body: some View {
        let imageSize = testImage.size(in: frameSize)
        let frameSize = frameSize.width > 0 && frameSize.height > 0 ? frameSize : TestImage.placeholderFrameSize
        let scale = maxSide / max(frameSize.width, frameSize.height, imageSize.width, imageSize.height)
        
        ZStack {
            Rectangle()
                .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: frameSize.width * scale, height: frameSize.height * scale)
            
            Rectangle()
                .fill(testImage.color)
                .frame(width: max(imageSize.width * scale, 1), height: max(imageSize.height * scale, 1))
        }
        .frame(width: maxSide, height: maxSide)
        .accessibilityHidden(true)
    }
}
