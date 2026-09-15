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
Add `ZoomImageView` as an overlay and pass it a binding to an optional `UIImage`. The view shows nothing while the binding is `nil`, and presents the image fullscreen as soon as one is set. Closing the viewer sets the binding back to `nil`, and setting the binding to `nil` closes the viewer with the same fade.

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
- Tap once to show or hide the overlay.
- Tap the close button.

Like in Photos, zooming in hides the overlay, status bar and home indicator so nothing covers the image. They come back when the image is zoomed back out to fit. A single tap shows or hides the overlay at any zoom, taking the status bar and home indicator with it only while the image is zoomed out, so a zoomed in image keeps the whole screen. Hiding the home indicator needs iOS 16.

Zooming and panning respect the reduce motion and smart invert accessibility settings.

With VoiceOver, the viewer acts as a modal: focus moves into it when it appears, content behind it is hidden, and the escape gesture, a two-finger scrub, dismisses the image. The image is a single element described by the `UIImage`'s `accessibilityLabel`, read before anything in the overlay and announced when it replaces another image, so set one to tell VoiceOver users what it shows.

```swift
let image = UIImage(named: "testImage")
image?.accessibilityLabel = String(localized: "Two eagles catching a fish")
uiImage = image
```

VoiceOver users can zoom and pan the image too. On iOS 16 and up, VoiceOver's zoom action zooms in and out like a double tap, always centring on the middle of the screen, as a VoiceOver gesture can be made anywhere. A three-finger swipe moves a zoomed-in image half a screen at a time, and VoiceOver plays its border sound when the image cannot move any further in that direction. The image's Show Controls and Hide Controls actions do the same as a single tap, so an overlay hidden by zooming in can be brought back without zooming out.

## Close button position
The close button sits in the top leading corner by default and can be moved to any `Alignment`. On iOS 26 and up it is also moved clear of system UI in the window's corners, like the traffic lights on an iPad window.

```swift
ZoomImageView(uiImage: $uiImage, closeButtonPosition: .topTrailing)
```

## Close button
The built-in close button, `ZoomImageCloseButton`, uses `ButtonRole.close` on iOS 26 and up, so its label comes from the system and is already localized. Earlier versions use an xmark icon titled "Close" from the package's string catalog.

Its default style, `ZoomImageDefaultButtonStyle`, renders as a Liquid Glass button on iOS 26 and as `ZoomImageCloseButtonStyle` on earlier versions.

## Overlay
Everything shown over the image, including the close button, is an overlay you can replace. The viewer covers its frame with the overlay, fades it in and out with the image, and hides it while the image is zoomed in or after a single tap. The overlay is inside the viewer's VoiceOver modal, so anything you put in it can be reached.

The overlay's views are stacked on top of each other inside the viewer's safe area, and placing and padding them is up to you. Use `ZoomImageDefaultOverlay` to keep the default close button, in its default position, alongside your own views.

```swift
ZoomImageView(uiImage: $uiImage) {
    ZoomImageDefaultOverlay(closeButtonPosition: .topTrailing)

    Text("Two eagles catching a fish")
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
}
```

A custom overlay replaces the default one, so include a close button unless dragging the image away is the only way you want to close it.

On iOS 26 and up, windows can have system UI in their corners, like the traffic lights on an iPad window. The default overlay moves its close button clear of them. Do the same for views you place in a corner with `containerCornerOffset(_:sizeToFit:)`.

### Button styles
Buttons in the overlay use `ZoomImageDefaultButtonStyle` unless they set their own. Any button style will do, including system styles like `.glass` or `.bordered`. Use `.buttonStyle(.automatic)` for the system's usual look.

```swift
ZoomImageView(uiImage: $uiImage) {
    ZoomImageDefaultOverlay()
        .buttonStyle(.glass)
}
```

Use `ZoomImageCloseButtonStyle` to adjust the color, blend mode and padding of the classic close button. Its defaults are a white label drawn with the `difference` blend mode, which keeps it visible on top of any image.

```swift
ZoomImageView(uiImage: $uiImage) {
    ZoomImageDefaultOverlay()
        .buttonStyle(ZoomImageCloseButtonStyle(color: .pink, blendmode: .normal, paddingAmount: 0))
}
```

A custom style given to the built-in close button receives the system close label on iOS 26 and up, and a `Label` with an xmark icon on earlier versions, so it can use the icon, the text, or both.

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

ZoomImageView(uiImage: $uiImage) {
    ZoomImageDefaultOverlay()
        .buttonStyle(MyCustomButtonStyle())
}
```

### Placing the close button yourself
`ZoomImageCloseButton` is the built-in button on its own, without a position or padding.

```swift
ZoomImageView(uiImage: $uiImage) {
    ZoomImageCloseButton()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
}
```

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

Use `closeZoomImage` rather than `dismiss`. The viewer is an overlay, not a presentation, so `dismiss` closes whatever presentation the viewer is in, like a sheet, and leaves the image showing.

## Rotation
If your app is locked to portrait but you want fullscreen images to rotate, wrap the viewer in `AutoRotatingView` from [FrameUp](https://github.com/ryanlintott/FrameUp). The example app does this.

```swift
.overlay(
    AutoRotatingView {
        ZoomImageView(uiImage: $uiImage)
    }
)
```
