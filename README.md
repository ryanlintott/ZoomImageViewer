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

# Installation and Usage
This package is compatible with iOS 15+.

1. In Xcode go to `File -> Add Package Dependencies`
2. Paste in the repo's url: `https://github.com/ryanlintott/ZoomImageViewer` and select by version.
3. Import the package using `import ZoomImageViewer`

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
Add `ZoomImageView` as an overlay and pass it a binding to an optional `UIImage`. The view shows nothing while the binding is `nil`, and presents the image fullscreen as soon as one is set. Closing the viewer sets the binding back to `nil`.

```swift
@State private var uiImage: UIImage? = nil

var body: some View {
    Button("Show image") {
        uiImage = UIImage(named: "testImage")
    }
    .overlay(ZoomImageView(uiImage: $uiImage))
}
```

Inside the viewer you can:

- Pinch to zoom, or double tap to zoom in and out.
- Pan around a zoomed-in image.
- Drag a zoomed-out image away to dismiss it.
- Tap the close button.

Zooming and panning respect the reduce motion and smart invert accessibility settings.

## Close button position
The close button sits in the top leading corner by default and can be moved to any `Alignment`. Padding keeps it clear of system UI in the corners, like the traffic lights on an iPad window.

```swift
ZoomImageView(uiImage: $uiImage, closeButtonPosition: .topTrailing)
```

## Close button style
The default style, `ZoomImageDefaultCloseButtonStyle`, renders as a Liquid Glass button on iOS 26 and as `ZoomImageCloseButtonStyle` on earlier versions.

Use `ZoomImageCloseButtonStyle` to adjust the color, blend mode and padding of the classic close button. Its defaults are a white label drawn with the `difference` blend mode, which keeps it visible on top of any image.

```swift
ZoomImageView(uiImage: $uiImage, closeButtonStyle: ZoomImageCloseButtonStyle(color: .pink, blendmode: .normal, paddingAmount: 0))
```

Any `ButtonStyle` will do, so the close button can be replaced entirely. The button label is a `Label` so styles can use the icon, the text, or both.

```swift
struct MyCustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Text("Bye")
            .foregroundColor(.white)
            .padding()
            .background(Capsule().fill(.red))
            .rotationEffect(.degrees(configuration.isPressed ? 180 : 0))
            .padding()
    }
}

ZoomImageView(uiImage: $uiImage, closeButtonStyle: MyCustomButtonStyle())
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
