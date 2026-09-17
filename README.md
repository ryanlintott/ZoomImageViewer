# ZoomImageViewer

[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanlintott%2FZoomImageViewer%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanlintott/ZoomImageViewer)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanlintott%2FZoomImageViewer%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanlintott/ZoomImageViewer)
![License - MIT](https://img.shields.io/github/license/ryanlintott/ZoomImageViewer)
![Version](https://img.shields.io/github/v/tag/ryanlintott/ZoomImageViewer?label=version)
![GitHub last commit](https://img.shields.io/github/last-commit/ryanlintott/ZoomImageViewer)
[![Documentation](https://img.shields.io/badge/documentation-Swift%20Package%20Index-blue)](https://swiftpackageindex.com/ryanlintott/ZoomImageViewer/documentation/zoomimageviewer)
[![Mastodon](https://img.shields.io/badge/mastodon-@ryanlintott-5c4ee4.svg?style=flat)](http://mastodon.social/@ryanlintott)
[![Bluesky](https://img.shields.io/badge/bluesky-@ryanlintott-0285FF.svg?style=flat)](https://bsky.app/profile/ryanlintott.bsky.social)

# Overview
A fullscreen SwiftUI image viewer with smooth and bouncy pinch zooming, panning, double-tap zoom in and out, and swipe to dismiss.

# Demo App
The `Example` folder has an app that demonstrates the features of this package.

# Installation
Requires iOS 15+ and Swift 6.0+ (Xcode 16+).

In Xcode, choose **File › Add Package Dependencies…** and enter `https://github.com/ryanlintott/ZoomImageViewer`. Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/ryanlintott/ZoomImageViewer", from: "1.0.0")
```

Then `import ZoomImageViewer`.

# Documentation
Full API documentation is hosted on the [Swift Package Index](https://swiftpackageindex.com/ryanlintott/ZoomImageViewer/documentation/zoomimageviewer).

# Is this Production-Ready?
Really it's up to you. I currently use this package in my own [Old English Wordhord app](https://oldenglishwordhord.com/app).

Additionally, if you find a bug or want a new feature add an issue and I will get back to you about it.

# Support
ZoomImageViewer is open source and free but if you like using it, please consider supporting my work.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/X7X04PU6T)

- - -
# Features

## ZoomImageView
Add `ZoomImageView` as an overlay and pass it a binding to an optional `UIImage`. The view shows nothing while the binding is `nil`, and presents the image fullscreen as soon as one is set. Closing the viewer sets the binding back to `nil`, and setting the binding to `nil` closes the viewer with the same fade.

The viewer only fills the frame it is given, so overlay it on a view that covers the whole screen and add it as high up the hierarchy as you can. Overlaying a single button shows the image in that button's frame.

```swift
@State private var uiImage: UIImage? = nil

var body: some View {
    VStack {
        Button("Show image") {
            uiImage = UIImage(named: "testImage")
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
        ZoomImageView(uiImage: $uiImage)
    }
}
```

Interactive behaviors:

- Pinch to zoom and pan in the same gesture. Zooming is anchored to the center of your pinch.
- Pan around a zoomed-in image in a smooth scroll view that bounces.
- Double-tap to zoom in and out.
- Tap the close button or drag a zoomed-out image and toss it away to dismiss it.
- Tap to show or hide the overlay, status bar, and home indicator.

Automatic behaviors:
- The overlay keeps the same safe area while the image ignores it and pans to the edges.
- Zooming in or panning hides the overlay, status bar and home indicator so nothing covers the image. Zooming out brings everything back.

Accessibility features:
- Smart invert will not invert the image.
- Voice Control labels.
- VoiceOver support.
  - The viewer acts as a modal.
  - Support for zooming and panning on iOS 16 and up.
  - Accessibility action for showing/hiding overlay controls.
  - Escape gesture dismisses the image.
  - `UIImage.accessibilityLabel` is used for the accessibility label and is announced the image appears.
- Reduce motion
  - Double-tap zooming will crossfade.
  - Thumbnail transition is disabled.
- Accessibility Text sizes for the close button.

```swift
let image = UIImage(named: "testImage")
image?.accessibilityLabel = String(localized: "Two eagles catching a fish")
uiImage = image
```

## Thumbnail Transition
Present an optional `Identifiable` and `Equatable` item instead of a `UIImage` to grow the image from the item's thumbnail and shrink it back when the viewer closes. Dragging the image away shrinks it back into the thumbnail too, rather than throwing it off screen. Only the image is matched. The background and overlay fade in and out as usual.

Give each thumbnail the `zoomImageSource(for:selection:in:)` modifier with its item, the viewer's selection and a namespace, and pass the viewer the item binding, a key path to the item's image and the same namespace. The viewer animates opening as well as closing, so set the item without `withAnimation`. The image always grows and shrinks with the viewer's own spring, even when the item is changed inside an animation, and can't be shown or hidden without animating.

```swift
@Namespace private var namespace
@State private var selectedPhoto: Photo? = nil

var body: some View {
    ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            ForEach(photos) { photo in
                Button {
                    selectedPhoto = photo
                } label: {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                        .zoomImageSource(for: photo, selection: selectedPhoto, in: namespace)
                }
            }
        }
    }
    .overlay {
        ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace)
    }
}
```

The thumbnail is hidden while its image is showing and fades back in once the image has landed on it. It stays in place the whole time, so the layout around it doesn't change.

A custom overlay goes in a trailing closure, like with the other initializers, and receives the item. Use this item when adding any 

```swift
ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace) { photo in
    ZoomImageDefaultOverlay()

    Text(photo.caption)
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
}
```

Setting the selection to another item while the viewer is open swaps the image instantly, and closing shrinks it into that item's thumbnail.

The image key path should return the same `UIImage` instance every time, like a stored property does, as a different instance is shown as a replacement image. The image is fitted to the frame it grows from, so a thumbnail showing the whole image with `scaledToFit()` matches it most closely.

## Overlay
The default overlay is a close button in the top trailing corner but the `Alignment` can be customized.

```swift
ZoomImageView(uiImage: $uiImage, closeButtonPosition: .topLeading)
```

The built-in close button, `ZoomImageCloseButton`, uses `ButtonRole.close` on iOS 26 and up, so its label comes from the system and is already localized. Earlier versions are titled "Close" from the package's string catalog.

Its default style, `ZoomImageDefaultButtonStyle`, renders as a Liquid Glass button on iOS 26. On earlier versions it shows the close button as a white xmark on a blurred dark circle, drawn in the dark colour scheme so it looks the same in light and dark mode.

If you want a custom overlay you can use a trailing closure and add additional UI elements. Use `ZoomImageDefaultOverlay` to keep the default close button, alongside your own views.

```swift
ZoomImageView(uiImage: $uiImage) {
    ZoomImageDefaultOverlay(closeButtonPosition: .topLeading)

    Text("Two eagles catching a fish")
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
}
```

`ZoomImageCloseButton` is the built-in button on its own, without a position or padding. All Buttons in the overlay use `ZoomImageDefaultButtonStyle` unless they set their own.

### Your own close button
To change the title, role or accessibility too, make a button that sets your image binding to `nil`, or calls the `closeZoomImage` action from the environment when the button is its own view. Localize its title in your own bundle as you would any other `Text`.

```swift
struct DoneButton: View {
    @Environment(\.closeZoomImage) private var closeZoomImage

    var body: some View {
        Button("Done", systemImage: "xmark", role: .close) {
            closeZoomImage()
        }
    }
}

ZoomImageView(uiImage: $uiImage) {
    DoneButton()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
}
```

## Rotation
If your app is locked to portrait but you want fullscreen images to rotate, wrap the viewer in `AutoRotatingView` from [FrameUp](https://github.com/ryanlintott/FrameUp). The example app does this.

```swift
.overlay(
    AutoRotatingView {
        ZoomImageView(uiImage: $uiImage)
    }
)
```
