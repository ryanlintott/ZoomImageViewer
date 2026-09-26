# Changelog

## Unreleased

### Breaking Changes

- Raised the minimum supported iOS version from 14 to 15.
- Raised the Swift tools version to 6.0. The package now builds in the Swift 6 language mode and needs Swift 6.0 or later.
- `ZoomImageView`'s generic parameter is now its overlay instead of its close button style. Only code that names the type is affected: `ZoomImageView<ZoomImageDefaultCloseButtonStyle>` becomes `ZoomImageView<ZoomImageDefaultOverlay>`, and a view made with the deprecated `closeButtonStyle` initializer is a `ZoomImageView<AnyView>`.

### Added

- `zoomImageViewer(uiImage:closeButtonPosition:wrapper:)` and `zoomImageViewer(uiImage:wrapper:overlay:)` view modifiers, which replace `ZoomImageView`. The viewer is placed over the view the modifier is attached to.
- `zoomImageViewer(item:image:closeButtonPosition:wrapper:)` and `zoomImageViewer(item:image:wrapper:overlay:)` present an optional `Identifiable` and `Equatable` item instead of a `UIImage`. The item is passed into the overlay allowing more information like a caption to be displayed. Additionaly if the source image uses `zoomImageSource(id:)` it can grow and shrink from the thumbnail when presented. The image is read through a key path.
- `zoomImageSource(id:)` so that a viewer with an `Identifiable` item's image grows from its source view, usually a thumbnail, and shrinks back when the viewer closes.
- An overlay closure for replacing everything shown over the image, such as the close button, other controls or captions. The overlay fades in and out with the image and can be reached with VoiceOver.
- `ZoomImageDefaultOverlay`, the default overlay, for keeping the default close button in a custom overlay. Restyle it with `buttonStyle(_:)` while keeping its localized label and position.
- With no `closeButtonPosition`, the default close button goes where a system close button on a fullscreen sheet would. On iOS 27.1 and up it avoids the system UI the container reserves: at the top of a vertical bar, like on iPhone Duo, beside a status bar in a top corner, and otherwise concentric with the top trailing corner, following a wrapper that turns the viewer. Earlier versions keep it in the top trailing corner. `closeButtonPosition` is now an optional `Alignment` that defaults to `nil`, and passing a position works as before.
- `ZoomImageCloseButton`, the built-in close button without a position, for placing yourself.
- `dismissZoomImage`, an environment action of type `ZoomImageDismissAction` that dismisses the viewer, for making your own close button in an overlay.
- `ZoomImageDefaultButtonStyle` now has an init so it can be used outside the package.
- Zooming or panning the image in hides the overlay, status bar and home indicator, so nothing covers the part being looked at. They come back once the image is zoomed back out to fit. A single tap on the image or the space around it shows or hides the overlay at any zoom, as does the image's Show Controls or Hide Controls accessibility action. The status bar and home indicator go with it only while the image is zoomed out.
- Dragging the image to dismiss it hides the overlay as the drag starts, and it fades back in if the image is put back.
- A `ZoomImageViewerWrapper` type passed to a `zoomImageViewer` modifier wraps that viewer in another view, like `AutoRotatingView` from FrameUp for an app locked to portrait.
- VoiceOver users can dismiss the image with the escape gesture.
- The viewer is modal to VoiceOver. Focus moves into it when it appears and back out when it is dismissed, and the content behind it can no longer be reached.
- The image is a VoiceOver element with the image trait, labelled with the `UIImage`'s `accessibilityLabel`. It was not reachable before, so a viewer without a close button had nothing to focus. It comes before the overlay, so VoiceOver reads it first.
- On iOS 16 and up, VoiceOver users can zoom the image in and out with VoiceOver's zoom action, the same as a double tap. Zooming in centres on the middle of the screen rather than where the gesture was made.
- VoiceOver users can pan a zoomed in image with three-finger swipes, half a screen at a time. VoiceOver plays its border sound when the image cannot move any further in that direction.
- Voice Control users can target the image by saying "Image", "Photo" or "Picture", as in "Tap Image". The names are translated into the same 48 languages as the close button.
- Replacing the image on screen announces the new image's `accessibilityLabel` to VoiceOver, as focus stays on whatever control swapped it.
- Translations of the built-in close button's "Close" title, used before iOS 26, in the 48 languages SwiftUI translates it into, using the same words as the system close button.
- Shared `ZoomImageViewer.xcworkspace` and `ZoomImageViewer Development` scheme for package and example-app development.
- Swift Package Index configuration for building and hosting the package's documentation.
- GitHub Actions workflow testing Swift 6.0 compatibility and building and testing on iOS with the current Swift version.
- This changelog.
- Unit tests for the zoom scale limits, image fitting and centring, vector normalization, zoom state equality, the drag dismiss animation, rotation, VoiceOver scrolling and the presentation state.

### Deprecated

- `ZoomImageCloseButtonStyle`. The overlay now hides while the image is zoomed in, so the close button no longer needs a discreet style. Use `ZoomImageDefaultButtonStyle` or a system button style instead.
- `ZoomImageView`, replaced by the `zoomImageViewer(uiImage:closeButtonPosition:wrapper:)` modifier. Use `.zoomImageViewer(uiImage: $uiImage)` in place of `ZoomImageView(uiImage:)`.
- `ZoomImageView(uiImage:closeButtonStyle:closeButtonPosition:)`. Use `zoomImageViewer(uiImage:wrapper:overlay:)` with `ZoomImageDefaultOverlay` and `buttonStyle(_:)` in the overlay instead.
- `ZoomImageView(uiImage:closeButtonPosition:)`. Use `zoomImageViewer(uiImage:closeButtonPosition:wrapper:)` instead.
- `ZoomImageDefaultCloseButtonStyle`, renamed to `ZoomImageDefaultButtonStyle` as it now styles every button in the overlay.

### Changed

- The image now ignores the safe area. It is fitted and centred in the whole screen, and a zoomed in image can be panned right to the edges, under the status bar, Dynamic Island and home indicator. It used to be inset by the window's safe area, which stopped a zoomed in image short of the edges. The overlay is still laid out inside the safe area.
- Setting the image binding to `nil` fades the viewer out like the close button does. It used to disappear immediately unless the change was animated. The viewer stays in the view hierarchy as a clear view while no image is shown, so it can finish fading out.
- The viewer fades in and out faster, in 0.3 seconds instead of 0.4.
- The default close button position is now the top trailing corner instead of the top leading corner. Pass `closeButtonPosition: .topLeading` to keep it where it was.
- A zoomed out image can be pinched or dragged away from the empty space around it as well as from the image itself. Only the image used to respond.
- Double tapping a partially zoomed image now zooms out instead of in.
- The viewer forces the dark colour scheme on everything inside it. This may change the appearance of custom button styles.
- `ZoomImageDefaultButtonStyle` no longer forces the dark colour scheme on itself before iOS 26. Inside a viewer it looks the same, as the viewer forces it instead. Used outside a viewer, the style now follows the colour scheme it is given like any other button style.
- Before iOS 26, the default close button is a white xmark on a blurred dark circle, like a standard close button over media, instead of a white xmark drawn with the `difference` blend mode. Other icon buttons in the overlay are drawn in the primary colour without a circle.
- On iOS 26 and up the built-in close button uses `ButtonRole.close` with the label the system provides, which is localized by the system.
- Rewrote the readme with badges, installation steps, examples for each feature and a note that the viewer shows behind any open sheet, as it is not presented as a full screen cover.
- Added a DocC landing page.
- The example app supports French, so the package's localized strings, like the close button's title and the Show Controls and Hide Controls actions, can be tested in another language. The example app's own strings are not translated.
- The example app has an app icon.
- The example app's minimum deployment target is now iOS 15, matching the package. Xcode 26 no longer builds for iOS 14, so the example app would not compile.
- Tests now use Swift Testing instead of XCTest.

### Fixed

- An image dragged away to dismiss carries on at the speed it was thrown, speeding up if needed to leave the screen in time. It used to spring away, starting slower than the throw before jumping to a faster speed.
- The image, overlay and drag to dismiss don't respond to touches until the image has finished appearing, so an early touch can't zoom, move or dismiss an image that hasn't arrived.
- Zooming, double tap and drag to dismiss no longer stop working when the image has the same aspect ratio as the screen, such as a screenshot taken on the same device. The shape that blocked gestures in the empty space around the image covered the whole screen in that case, and is now gone.
- All images now have a maximum zoom 2x the image size or 2x the frame size, whichever is greater. An image that fits the screen at a zoom scale of 1 used to not scale at all but now it will now zoom up to 2x.
- Images smaller than the screen now fill it and can be zoomed. They need a zoom scale above 1 just to fit, which was larger than the maximum zoom scale, so they rendered small and would not zoom at all. The maximum zoom scale is now never below the scale needed to fit, and allows zooming to twice that. Images at least as large as the screen are unaffected.
- The close button's "Close" title is now localized within the package. It was previously looked up in the app's bundle, so it could only be localized if the app happened to have a "Close" key.
- Presenting an image always starts zoomed out and interactive rather than inheriting the zoom state of a previous one.
- Pinch zooming no longer centres the image against the frame size from when it first appeared. The scroll view delegate held the first version of the view it was given, so after a rotation or a window resize it inset the image using the old size.
- Updating the viewer part way through a pinch no longer snaps the image back to the scale the pinch started from. Every update reapplied the zoom state, which a pinch doesn't change until it ends, so a change to the overlay's state while pinching zoomed a fitted image back out.
- Scroll edge effects are hidden, so they no longer blur an edge of the image, which could happen from iOS 27 in a viewer rotated with `AutoRotatingView` from FrameUp.
- An image with no size, such as an empty `UIImage`, no longer gives an infinite minimum zoom scale that was handed to the scroll view. Either the image or the frame having no width or height now leaves the zoom scale at 1.
- Dragging an image away no longer divides by zero when the drag has no length, which gave an offset of `NaN`. A vector with no length now normalizes to zero.
- Replacing the image without setting the binding to `nil` in between now shows the new image immediately, with no transition, in a new scroll view at its own size and zoomed out. Presenting an image when there is nothing on screen still fades in, and dismissing one still fades out. Previously the new image was swapped into the scroll view already on screen, which kept the frame it was built with, so an image of a different size was stretched to fit the previous one's frame.
- The example app's local package reference now points at `..` instead of `../../ZoomImageViewer`, so it no longer depends on the name of the folder containing the repository.

### Removed

- Unused internal `Shape.scaleToFit(_:aspectRatio:)` extension.
- `Comparable` conformance on the internal `ZoomState`. Nothing used the ordering, so it is now just `Equatable`.

## 0.6.4 - 2026-06-10

### Breaking Changes

- Replaced `ZoomImageGlassCloseButtonStyle` with `ZoomImageDefaultCloseButtonStyle`, which chooses an appearance for the running version instead of only existing on iOS 26 and up.

### Fixed

- The default close button renders as a Glass button on iOS 26 and up again, and as `ZoomImageCloseButtonStyle` on earlier versions. It had used the earlier style everywhere since 0.6.2.

## 0.6.3 - 2026-05-04

### Fixed

- `closeButtonPosition` is no longer a required parameter when creating a `ZoomImageView` with the default close button style.

## 0.6.2 - 2026-05-04

### Breaking Changes

- `closeButtonStyle` is no longer optional. Pass a non-optional button style or omit the argument to use the default style. This also meant the default close button always used `ZoomImageCloseButtonStyle`, even on iOS 26, until 0.6.4.

### Added

- `closeButtonPosition` parameter for placing the close button at any `Alignment` within the viewable frame.

### Fixed

- The close button is now padded away from the corners so it never sits behind system UI, like the traffic lights on an iPad window.

## 0.6.1 - 2025-09-11

### Fixed

- Images now offset again when dragged to dismiss on iOS 26.

## 0.6.0 - 2025-07-28

### Added

- `ZoomImageGlassCloseButtonStyle`, a Liquid Glass close button style for iOS 26 and up, used as the default there.
- Drag to dismiss now accounts for gesture velocity on iOS 17 and up, based on the dismiss distance, so tossing an image away feels smoother.
- Fade-out animation for the image, delayed to halfway through the dismissal, in case the image is somehow still on screen when the animation ends.

### Changed

- The close button now fades in after the image is showing.
- Removed an unnecessary `Sendable` annotation from `ZoomImageCloseButtonStyle`.
- The example app now demonstrates each of the close button options.

## 0.5.3 - 2025-07-26

### Fixed

- Scrolling and zooming gestures now register outside the pre-zoomed image area. Zooming works on the image when fully zoomed out, zooming and panning work anywhere when partially zoomed in, and dragging the image away to dismiss it still only works on the image itself.

### Changed

- Removed unnecessary `MainActor` annotations.

## 0.5.2 - 2025-07-25

### Fixed

- Performance issues when scrolling and zooming quickly.

### Changed

- `ZoomImageViewRepresentable` now takes a `UIImage` instead of a `UIView`, and `isInteractive` is no longer a binding.

## 0.5.1 - 2024-10-08

### Added

- The example app now lives in the `Example` folder inside this package instead of a separate repository.

## 0.5.0 - 2024-08-13

### Breaking Changes

- Renamed `ZoomImageViewer` to `ZoomImageView` to avoid a name conflict with the package.
- Renamed `FullScreenImageView` to `_ZoomImageView` and `ImageZoomView` to `ZoomImageViewRepresentable`.

### Added

- Swift 6 support, including strict concurrency checking and a privacy manifest.

### Changed

- Raised the Swift tools version to 5.9.
- The close button now uses a `Label` and renders only the icon, which reads better in accessibility tools than an accessibility label alone.
- Replaced `edgesIgnoringSafeArea` with `ignoresSafeArea`.

## 0.4.1 - 2022-09-23

### Fixed

- Images are no longer inverted when Smart Invert is on.
- Double tap to zoom is no longer animated when Reduce Motion is on.

## 0.4 - 2022-09-19

### Breaking Changes

- Removed `CloseButton` and replaced it with `ZoomImageCloseButtonStyle`. The viewer now takes a `ButtonStyle` instead of a close button view.
- Removed `RotationMatchingOrientationViewModifier`. Use [FrameUp](https://github.com/ryanlintott/FrameUp) for this instead.
- Removed the `InfoDictionary` and `UIDeviceOrientation` extensions, which were only needed by the rotation modifier.
- `CGSize.max` is now internal instead of public.

### Added

- Documentation comments across the public API.

### Fixed

- Animated rotations, though safe areas still do not animate correctly.

## 0.3 - 2022-05-04

### Breaking Changes

- Removed `isRotatable`, so views can rotate regardless of the orientations the app supports. This allows locking a view to a specific orientation even when the phone allows another one.

### Changed

- `allowedOrientations` no longer always includes `.portrait`.
- The default orientation is now the first of `allowedOrientations`.

## 0.2 - 2021-05-19

### Added

- `InfoDictionary` and `UIDeviceOrientation` extensions for reading the supported interface orientations.

### Changed

- The rotation modifier now tracks device rotation as well as content rotation, so changes are relative.
- Removed the device and size class checks, which are no longer necessary.

## 0.1.2 - 2021-02-18

### Added

- Detection for slide over and split view apps on iPad.

## 0.1.1 - 2021-01-13

### Changed

- Removed `Comparable` conformance from `CGSize` and `CGPoint` to keep them private.

## 0.1.0 - 2021-01-13

### Added

- Initial release. A fullscreen image viewer with pinch zooming, panning, double tap to zoom, drag to dismiss, a customizable close button, and `RotationMatchingOrientationViewModifier`.
