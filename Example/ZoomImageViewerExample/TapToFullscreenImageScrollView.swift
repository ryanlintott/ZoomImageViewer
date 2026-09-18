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
        case defaultTopLeading
        case customButtonStyle
        
        var id: Self {
            self
        }
        
        var name: String {
            switch self {
            case .default: "Liquid Glass"
            case .defaultTopLeading: "Liquid Glass, top leading"
            case .customButtonStyle: "Custom Button Style"
            }
        }
        
        var detail: String? {
            switch self {
            case .default: "Before iOS 26: white xmark on a blurred dark circle"
            case .defaultTopLeading: "The default close button moved to the top leading corner"
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
    /// The photo shown in the third viewer, which fades in and out with no thumbnail to grow from.
    @State private var fadedPhoto: ThumbnailPhoto? = nil
    
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
                                .zoomImageSource(for: photo, selection: selectedPhoto, namespace: namespace)
                                .frame(height: 80)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(photo.caption)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(verbatim: "Thumbnails")
            } footer: {
                Text(verbatim: "Each thumbnail is a source view, marked with zoomImageSource. Images grow from them and shrink back into them when closed.")
            }
            
            Section {
                ForEach(ThumbnailPhoto.all) { photo in
                    Button {
                        fadedPhoto = photo
                    } label: {
                        HStack {
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFit()
                                .accessibilityIgnoresInvertColors()
                                .frame(width: 80, height: 44)

                            Text(photo.caption)
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(verbatim: "Items without a namespace")
            } footer: {
                Text(verbatim: "The same photos in a viewer with no namespace. The image fades in and out instead of growing from a thumbnail, and the overlay still receives the item.")
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
                Text(verbatim: "Close button styles")
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
                Text(verbatim: "Image sizes")
            } footer: {
                Text(verbatim: "Sizes are relative to the \(TestImage.sizeDescription(viewerSize)) viewer frame. Use the arrows while an image is showing to swap to the next or previous one.")
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
                    
                    ZoomImageView(uiImage: $uiImage) { _ in
                        switch closeButtonOption {
                        case .default:
                            ZoomImageDefaultOverlay()
                        case .defaultTopLeading:
                            ZoomImageDefaultOverlay(closeButtonPosition: .topLeading)
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
                ZoomImageView(item: $selectedPhoto, image: \.image, namespace: namespace) { photo in
                    ZoomImageDefaultOverlay()
                    
                    /// Built for the photo on screen, and kept while the viewer fades out.
                    photoControls(for: photo)
                        .padding()
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        )
        .overlay(
            /// A third viewer taking the same items with no namespace, so the image fades in and out rather than growing from a thumbnail.
            AutoRotatingView {
                ZoomImageView(item: $fadedPhoto, image: \.image) { photo in
                    ZoomImageDefaultOverlay()

                    /// A plain caption in the viewer's own semantic colours. The viewer forces the dark colour scheme, so `.secondary` is the one for a dark background even while the app is in light mode.
                    Text(photo.caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        )
    }
    
    /// Steps between photos while one is on screen. Closing after a step shrinks the image into the thumbnail of the photo on screen.
    func photoControls(for photo: ThumbnailPhoto) -> some View {
        StepControls(title: photo.caption, previousTitle: "Previous photo", nextTitle: "Next photo") {
            stepPhoto(from: photo, by: -1)
        } next: {
            stepPhoto(from: photo, by: 1)
        }
    }
    
    func stepPhoto(from photo: ThumbnailPhoto, by offset: Int) {
        let all = ThumbnailPhoto.all
        guard let index = all.firstIndex(where: { $0.id == photo.id }) else { return }
        selectedPhoto = all.element(at: index, offsetBy: offset)
    }
    
    /// Steps between test images while one is on screen, to check the swap animation.
    var imageSwapControls: some View {
        StepControls(title: testImage.name, previousTitle: "Previous image", nextTitle: "Next image") {
            step(by: -1)
        } next: {
            step(by: 1)
        }
    }
    
    func show(_ testImage: TestImage) {
        self.testImage = testImage
        uiImage = testImage.image(in: viewerSize)
    }
    
    func step(by offset: Int) {
        let allCases = TestImage.allCases
        guard let index = allCases.firstIndex(of: testImage) else { return }
        show(allCases.element(at: index, offsetBy: offset))
    }
}

/// Previous and next buttons either side of a title, for stepping between images while one is on screen.
struct StepControls: View {
    let title: String
    let previousTitle: String
    let nextTitle: String
    let previous: () -> Void
    let next: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: previous) {
                Label {
                    Text(previousTitle)
                } icon: {
                    Image(systemName: "chevron.left")
                }
            }
            
            Text(title)
                .font(.subheadline)
                .frame(minWidth: 140)
            
            Button(action: next) {
                Label {
                    Text(nextTitle)
                } icon: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        /// Opts out of the overlay's default button style.
        .buttonStyle(.automatic)
        .labelStyle(.iconOnly)
        .font(.title3)
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
    }
}

extension Array {
    /// The element `offset` places from `index`, wrapping around either end.
    func element(at index: Int, offsetBy offset: Int) -> Element {
        self[((index + offset) % count + count) % count]
    }
}

struct MyCustomButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Text(verbatim: "Bye")
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
