# ``ZoomImageViewer``

A fullscreen SwiftUI image viewer with smooth and bouncy pinch zooming, panning, double-tap zoom in and out, and swipe to dismiss.

## Overview

Attach the ``SwiftUICore/View/zoomImageViewer(uiImage:closeButtonPosition:)`` modifier to a view and pass it a binding to an optional `UIImage`. The viewer shows nothing while the binding is `nil`, presents the image fullscreen as soon as one is set, and sets the binding back to `nil` when it closes.

The viewer covers the view it is attached to, so attach it to a view that covers the whole screen, as high up the hierarchy as you can.

```swift
@State private var uiImage: UIImage? = nil

var body: some View {
    VStack {
        Button("Show image") {
            uiImage = UIImage(named: "testImage")
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .zoomImageViewer(uiImage: $uiImage)
}
```

Present an `Identifiable` and `Equatable` item instead, with a key path to its image, when the overlay needs more than the image itself, like a caption, or to grow the image from a source view. The overlay closure receives the item.

```swift
.zoomImageViewer(item: $selectedPhoto, image: \.image)
```

The image grows from its item's source view, usually a thumbnail, and shrinks back when the viewer closes, instead of fading in and out. Give each source view inside the view the viewer is attached to ``SwiftUICore/View/zoomImageSource(for:)`` with its item. The image is matched to its source by the item's `id`, and fades in and out when its item has no source on screen.

```swift
LazyVGrid(columns: columns) {
    ForEach(photos) { photo in
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFit()
            .zoomImageSource(for: photo)
    }
}
.zoomImageViewer(item: $selectedPhoto, image: \.image)
```

Everything shown over the image is an overlay you can replace. Keep the built-in close button with ``ZoomImageDefaultOverlay``, place ``ZoomImageCloseButton`` yourself, or make your own button that calls ``SwiftUICore/EnvironmentValues/dismissZoomImage``. Buttons in the overlay use ``ZoomImageDefaultButtonStyle`` unless they set their own.

Wrap every viewer in another view, like `AutoRotatingView` from FrameUp for an app locked to portrait, with ``SwiftUICore/View/zoomImageViewerWrapper(_:)``.

The background is black in both light and dark mode and the viewer forces the dark colour scheme on everything inside it.

The viewer supports VoiceOver, Reduce Motion and Smart Invert.

Requires iOS 15+.

For a feature-by-feature guide with examples, see the [README](https://github.com/ryanlintott/ZoomImageViewer), and the `Example` folder in the [repository](https://github.com/ryanlintott/ZoomImageViewer) for a demo app.

## Topics

### Viewer

- ``SwiftUICore/View/zoomImageViewer(uiImage:closeButtonPosition:)``
- ``SwiftUICore/View/zoomImageViewer(uiImage:overlay:)``
- ``SwiftUICore/View/zoomImageViewerWrapper(_:)``
- ``ZoomImageViewerContent``

### Items and Source Views

- ``SwiftUICore/View/zoomImageViewer(item:image:closeButtonPosition:)``
- ``SwiftUICore/View/zoomImageViewer(item:image:overlay:)``
- ``SwiftUICore/View/zoomImageSource(for:)``

### Overlay

- ``ZoomImageDefaultOverlay``
- ``ZoomImageCloseButton``
- ``ZoomImageDefaultButtonStyle``

### Dismissing

- ``SwiftUICore/EnvironmentValues/dismissZoomImage``
- ``ZoomImageDismissAction``

### Deprecated

- ``ZoomImageView``
- ``ZoomImageCloseButtonStyle``
- ``ZoomImageDefaultCloseButtonStyle``
