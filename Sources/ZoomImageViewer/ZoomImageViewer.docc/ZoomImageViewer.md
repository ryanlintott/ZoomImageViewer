# ``ZoomImageViewer``

A fullscreen SwiftUI image viewer with smooth and bouncy pinch zooming, panning, double-tap zoom in and out, and swipe to dismiss.

## Overview

Add ``ZoomImageView`` as an overlay and pass it a binding to an optional `UIImage`. The viewer shows nothing while the binding is `nil`, presents the image fullscreen as soon as one is set, and sets the binding back to `nil` when it closes.

The viewer only fills the frame it is given, so overlay it on a view that covers the whole screen, as high up the hierarchy as you can.

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

Present an `Identifiable` item instead of an image to grow the image from its thumbnail and shrink it back when the viewer closes. Give each thumbnail ``SwiftUICore/View/zoomImageSource(for:selection:in:)`` and pass the viewer the same namespace.

```swift
Image(uiImage: photo.image)
    .resizable()
    .scaledToFit()
    .zoomImageSource(for: photo, selection: selectedPhoto, in: namespace)

ZoomImageView(item: $selectedPhoto, image: \.image, in: namespace)
```

Everything shown over the image is an overlay you can replace. Keep the built-in close button with ``ZoomImageDefaultOverlay``, place ``ZoomImageCloseButton`` yourself, or make your own button that calls ``SwiftUICore/EnvironmentValues/closeZoomImage``. Buttons in the overlay use ``ZoomImageDefaultButtonStyle`` unless they set their own.

The viewer supports VoiceOver, Reduce Motion and Smart Invert.

Requires iOS 15+.

For a feature-by-feature guide with examples, see the [README](https://github.com/ryanlintott/ZoomImageViewer), and the `Example` folder in the [repository](https://github.com/ryanlintott/ZoomImageViewer) for a demo app.

## Topics

### Viewer

- ``ZoomImageView``

### Growing from a Thumbnail

- ``SwiftUICore/View/zoomImageSource(for:selection:in:)``
- ``ZoomImageItemOverlay``

### Overlay

- ``ZoomImageDefaultOverlay``
- ``ZoomImageCloseButton``
- ``ZoomImageDefaultButtonStyle``

### Closing

- ``SwiftUICore/EnvironmentValues/closeZoomImage``
- ``ZoomImageCloseAction``

### Deprecated

- ``ZoomImageCloseButtonStyle``
- ``ZoomImageDefaultCloseButtonStyle``
