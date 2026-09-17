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
        
        /// Localized with `String(localized:)` rather than `LocalizedStringResource`, which needs iOS 16.
        var name: String {
            switch self {
            case .default: String(localized: "Liquid Glass", comment: "Close button option using the Liquid Glass style.")
            case .defaultZoomImageCloseButtonStyle: String(localized: "Default ZoomImageCloseButtonStyle", comment: "Close button option. ZoomImageCloseButtonStyle is a type name and is not translated.")
            case .customZoomImageCloseButtonStyle: String(localized: "Custom ZoomImageCloseButtonStyle", comment: "Close button option. ZoomImageCloseButtonStyle is a type name and is not translated.")
            case .customButtonStyle: String(localized: "Custom Button Style", comment: "Close button option using a button style defined by the example app.")
            }
        }
        
        var detail: String? {
            switch self {
            case .default: String(localized: "Fallback: Default ZoomImageCloseButtonStyle", comment: "Detail for the Liquid Glass option, naming the style used before iOS 26. ZoomImageCloseButtonStyle is a type name and is not translated.")
            default: nil
            }
        }
    }
    
    @State private var uiImage: UIImage? = nil
    @State private var closeButtonOption: CloseButtonOption = .default
    /// The test image on screen, used to step to the next or previous one.
    @State private var testImage: TestImage = .bundled
    /// The size of the frame the viewer shows images in, so test images can be sized relative to it.
    @State private var viewerSize: CGSize = .zero
    /// The photo shown in the second viewer, which grows from its thumbnail.
    @State private var selectedPhoto: ThumbnailPhoto? = nil
    
    @Namespace private var namespace
    
    var thumbnailImage: some View {
        Image(uiImage: TestImage.bundledImage)
            .resizable()
            .scaledToFit()
            .accessibilityIgnoresInvertColors()
            .frame(width: 80)
    }
    
    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach(ThumbnailPhoto.all) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFit()
                                .accessibilityIgnoresInvertColors()
                                .zoomImageSource(for: photo, selection: selectedPhoto, in: namespace)
                                .frame(height: 80)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(photo.caption)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Thumbnails", comment: "Header of the grid of thumbnails that grow into the viewer.")
            } footer: {
                Text("Images grow from these thumbnails and shrink back into them when closed.", comment: "Footer of the grid of thumbnails, explaining the matched geometry effect.")
            }
            
            Section {
                ForEach(CloseButtonOption.allCases) { option in
                    Button {
                        closeButtonOption = option
                        show(.bundled)
                    } label: {
                        HStack {
                            thumbnailImage
                            
                            VStack(alignment: .leading) {
                                Text(option.name)
                                    .font(.headline)
                                
                                if let detail = option.detail {
                                    Text(detail)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Close button styles", comment: "Header of the list of close button options.")
            }
            
            Section {
                ForEach(TestImage.allCases) { testImage in
                    Button {
                        show(testImage)
                    } label: {
                        HStack {
                            TestImageDiagram(testImage: testImage, frameSize: viewerSize)
                            
                            VStack(alignment: .leading) {
                                Text(testImage.name)
                                    .font(.headline)
                                
                                Text(testImage.detail)
                                    .font(.subheadline)
                                
                                Text(TestImage.sizeDescription(testImage.size(in: viewerSize)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Image sizes", comment: "Header of the list of test images.")
            } footer: {
                Text("Sizes are relative to the \(TestImage.sizeDescription(viewerSize)) viewer frame. Use the arrows while an image is showing to swap to the next or previous one.", comment: "Footer of the list of test images. The variable is the size of the viewer, like 402 × 874 pt.")
            }
        }
        .overlay(
            /// Auto rotating modifier is from FrameUp and is optional if you have an app that only uses portrait but you want to be able to view fullscreen images in landscape as well.
            AutoRotatingView {
                ZStack {
                    /// Holds the overlay at full size so the viewer frame can be measured even while no image is showing.
                    Color.clear
                        .onSizeChange {
                            viewerSize = $0
                        }
                        .ignoresSafeArea()
                    
                    ZoomImageView(uiImage: $uiImage) {
                        switch closeButtonOption {
                        case .default:
                            ZoomImageDefaultOverlay(closeButtonPosition: .topTrailing)
                        case .defaultZoomImageCloseButtonStyle:
                            ZoomImageDefaultOverlay()
                                .buttonStyle(ZoomImageCloseButtonStyle())
                        case .customZoomImageCloseButtonStyle:
                            ZoomImageDefaultOverlay()
                                .buttonStyle(ZoomImageCloseButtonStyle(color: .pink, blendmode: .normal, paddingAmount: 0))
                        case .customButtonStyle:
                            ZoomImageDefaultOverlay()
                                .buttonStyle(MyCustomButtonStyle())
                        }
                        
                        /// Inside the overlay so VoiceOver can reach it and it fades out with the image.
                        imageSwapControls
                            .padding()
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        )
        .overlay(
            /// A second viewer for the thumbnails, with its own selection. Turned by `AutoRotatingView` too, so the image is seen turning back to match its thumbnail as it lands.
            AutoRotatingView {
                ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace) { photo in
                    ZoomImageDefaultOverlay()
                    
                    /// Built for the photo on screen, and kept while the viewer fades out.
                    photoControls(for: photo)
                        .padding()
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        )
    }
    
    /// Steps between photos while one is on screen. Closing after a step shrinks the image into the thumbnail of the photo on screen.
    func photoControls(for photo: ThumbnailPhoto) -> some View {
        HStack(spacing: 16) {
            Button {
                stepPhoto(from: photo, by: -1)
            } label: {
                Label(String(localized: "Previous photo", comment: "Button that shows the previous thumbnail photo."), systemImage: "chevron.left")
            }
            
            Text(photo.caption)
                .font(.subheadline)
                .frame(minWidth: 140)
            
            Button {
                stepPhoto(from: photo, by: 1)
            } label: {
                Label(String(localized: "Next photo", comment: "Button that shows the next thumbnail photo."), systemImage: "chevron.right")
            }
        }
        /// Opts out of the overlay's default button style.
        .buttonStyle(.automatic)
        .labelStyle(.iconOnly)
        .font(.title3)
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    func stepPhoto(from photo: ThumbnailPhoto, by offset: Int) {
        let all = ThumbnailPhoto.all
        guard let index = all.firstIndex(where: { $0.id == photo.id }) else { return }
        selectedPhoto = all[(index + offset + all.count) % all.count]
    }
    
    /// Steps between test images while one is on screen, to check the swap animation.
    var imageSwapControls: some View {
        HStack(spacing: 16) {
            Button {
                step(by: -1)
            } label: {
                Label(String(localized: "Previous image", comment: "Button that shows the previous test image."), systemImage: "chevron.left")
            }
            
            Text(testImage.name)
                .font(.subheadline)
                .frame(minWidth: 140)
            
            Button {
                step(by: 1)
            } label: {
                Label(String(localized: "Next image", comment: "Button that shows the next test image."), systemImage: "chevron.right")
            }
        }
        /// Opts out of the overlay's default button style.
        .buttonStyle(.automatic)
        .labelStyle(.iconOnly)
        .font(.title3)
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    func show(_ testImage: TestImage) {
        self.testImage = testImage
        uiImage = testImage.image(in: viewerSize)
    }
    
    func step(by offset: Int) {
        let allCases = TestImage.allCases
        guard let index = allCases.firstIndex(of: testImage) else { return }
        show(allCases[(index + offset + allCases.count) % allCases.count])
    }
}

struct MyCustomButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Text("Bye", comment: "Title of a custom close button.")
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
