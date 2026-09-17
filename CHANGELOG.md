# Changelog

## Unreleased

### Breaking Changes

- Raised the minimum supported iOS version from 14 to 15.
- Raised the Swift tools version to 6.0. The package now builds in the Swift 6 language mode and needs Swift 6.0 or later.
- `ZoomImageView`'s generic parameter is now its overlay instead of its close button style. Only code that names the type is affected: `ZoomImageView<ZoomImageDefaultCloseButtonStyle>` becomes `ZoomImageView<ZoomImageDefaultOverlay>`, and a view made with the deprecated `closeButtonStyle` initializer is a `ZoomImageView<AnyView>`.

### Added

- `ZoomImageView(uiImage:overlay:)` for replacing everything shown over the image, such as the close button, other controls or captions. The overlay fades in and out with the image and can be reached with VoiceOver. Buttons in it can use any button style, including primitive styles like `.glass` and `.bordered` that `closeButtonStyle` cannot take.
- Translations of the built-in close button's "Close" title, used before iOS 26, in the 48 languages SwiftUI translates it into, using the same words as the system close button.
- `ZoomImageView(item:image:in:closeButtonPosition:)` and `ZoomImageView(item:image:in:overlay:)` present an optional `Identifiable` and `Equatable` item and grow its image from a thumbnail with the `zoomImageSource(for:selection:in:)` modifier when the viewer opens, and shrink it back when it closes. The item's `id` matches the image to its thumbnail, so the image and its thumbnail can't get out of sync, and closing after the selection changes shrinks the image into the thumbnail of the item on screen. The image always grows and shrinks with the viewer's own animation, whether or not the item is set inside an animation, so `withAnimation` isn't needed. The overlay closure receives the item, and keeps showing the last one while the viewer fades out. The thumbnail is hidden while its image is showing and never removed, so its layout and state are kept. Dragging the image away shrinks it back into the thumbnail from where it was dropped, carrying on at the speed it was thrown rather than turning on the spot. The close button, escape gesture and drag animate the close themselves. The image stays opaque until it lands on its thumbnail, which fades back in once it has. An image in a container that turns it, like `AutoRotatingView` from FrameUp, turns back as it lands on its thumbnail, rather than landing sideways and away from it. The example app has a grid of thumbnails that grow into a second viewer.
- `ZoomImageDefaultOverlay`, the default overlay, for keeping the default close button in a custom overlay. Restyle it with `buttonStyle(_:)` while keeping its localized label and position.
- `ZoomImageCloseButton`, the built-in close button without a position, for placing yourself.
- `closeZoomImage`, an environment action of type `ZoomImageCloseAction` that closes the viewer, for making your own close button in an overlay.
- A public initializer for `ZoomImageDefaultButtonStyle`. The style had none, so it could not be created outside the package.
- VoiceOver users can dismiss the image with the escape gesture.
- The viewer is modal to VoiceOver. Focus moves into it when it appears and back out when it is dismissed, and the content behind it can no longer be reached.
- The image is a VoiceOver element with the image trait, labelled with the `UIImage`'s `accessibilityLabel`. It was not reachable before, so a viewer without a close button had nothing to focus. It comes before the overlay, so VoiceOver reads it first.
- On iOS 16 and up, VoiceOver users can zoom the image in and out with VoiceOver's zoom action, the same as a double tap. Zooming in centres on the middle of the screen rather than where the gesture was made.
- VoiceOver users can pan a zoomed in image with three-finger swipes, half a screen at a time. VoiceOver plays its border sound when the image cannot move any further in that direction.
- Like in Photos, zooming the image in hides the overlay, status bar and home indicator, so nothing covers the part being looked at. They come back once the image is zoomed back out to fit. A single tap on the image or the space around it shows or hides the overlay at any zoom, as does the image's Show Controls or Hide Controls accessibility action. The status bar and home indicator go with it only while the image is zoomed out. An overlay shown over a zoomed in image hides again as soon as the image is panned or zoomed. The action names are translated into the same 48 languages as the close button, using the words VoiceOver reads for the same actions in the system video player, or the system's matching wording elsewhere where the video player's show and hide names don't match each other. The overlay can't be tapped or reached with VoiceOver while it is hidden. Hiding the home indicator needs iOS 16.
- Replacing the image on screen announces the new image's `accessibilityLabel` to VoiceOver, as focus stays on whatever control swapped it.
- Shared `ZoomImageViewer.xcworkspace` and `ZoomImageViewer Development` scheme for package and example-app development.
- Swift Package Index configuration for building and hosting the package's documentation.
- GitHub Actions workflow testing Swift 6.0 compatibility and building and testing on iOS with the current Swift version.
- This changelog.
- Unit tests for `CGSize.scaledToFit(_:)`.
- Unit tests for the zoom scale limits, vector normalization and zoom state equality.

### Deprecated

- `ZoomImageCloseButtonStyle`. The overlay now hides while the image is zoomed in, so the close button no longer needs a discreet style. Use `ZoomImageDefaultButtonStyle` or a system button style instead.
- `ZoomImageView(uiImage:closeButtonStyle:closeButtonPosition:)`. Put `ZoomImageDefaultOverlay` with `buttonStyle(_:)` in an overlay instead.
- `ZoomImageDefaultCloseButtonStyle`, renamed to `ZoomImageDefaultButtonStyle` as it now styles every button in the overlay.

### Changed

- Before iOS 26, the default close button is a white xmark on a blurred dark circle, like a standard close button over media, instead of a white xmark drawn with the `difference` blend mode. It is drawn in the dark colour scheme, so it looks the same in light and dark mode. Other icon buttons in the overlay are drawn in the primary colour without a circle.
- The default close button position is now the top trailing corner instead of the top leading corner, in `ZoomImageDefaultOverlay` and every `ZoomImageView` initializer that takes a `closeButtonPosition`. Pass `closeButtonPosition: .topLeading` to keep it where it was.
- Double tapping an image zoomed in by any amount, such as one pinched part way in, zooms it back out to fit. It used to zoom a partly zoomed image further in, and only zoomed out from the maximum.
- Like in Photos, the image ignores the safe area. It is fitted and centred in the whole screen, and a zoomed in image can be panned right to the edges, under the status bar, Dynamic Island and home indicator. It used to be inset by the window's safe area, which stopped a zoomed in image short of the edges. The overlay is still laid out inside the safe area.
- Setting the image binding to `nil` fades the viewer out like the close button does. It used to disappear immediately unless the change was animated. `ZoomImageView` stays in the view hierarchy as a clear view while no image is shown, so it can finish fading out.
- On iOS 26 and up the built-in close button uses `ButtonRole.close` with the label the system provides, which is localized by the system.
- Presenting an image always starts zoomed out and interactive rather than inheriting the zoom state of a previous one.
- Rewrote the readme with badges, installation steps, and examples for each feature.
- The example app supports French, so the package's localized strings, like the close button's title and the Show Controls and Hide Controls actions, can be tested in another language. The example app's own strings are not translated.
- The example app's minimum deployment target is now iOS 15, matching the package. Xcode 26 no longer builds for iOS 14, so the example app would not compile.
- The example app's local package reference now points at `..` instead of `../../ZoomImageViewer`, so it no longer depends on the name of the folder containing the repository.
- Tests now use Swift Testing instead of XCTest.

### Fixed

- The close button's "Close" title on versions before iOS 26 is now looked up in the package's own string catalog. It was looked up in the app's bundle, so it could only be localized if the app happened to have a "Close" key.
- Zooming, double tap and drag to dismiss no longer stop working when the image has the same aspect ratio as the screen, such as a screenshot taken on the same device. The shape blocking gestures in the empty space around the image covered the whole screen in that case.
- All images now have a maximum zoom 2x the image size or 2x the frame size, whichever is greater. An image that fits the screen at a zoom scale of 1 used to not scale at all but now it will now zoom up to 2x.
- Images smaller than the screen now fill it and can be zoomed. They need a zoom scale above 1 just to fit, which was larger than the maximum zoom scale, so they rendered small and would not zoom at all. The maximum zoom scale is now never below the scale needed to fit, and allows zooming to twice that. Images at least as large as the screen are unaffected.
- Pinch zooming no longer centres the image against the frame size from when it first appeared. The scroll view delegate held the first version of the view it was given, so after a rotation or a window resize it inset the image using the old size.
- Updating the viewer part way through a pinch no longer snaps the image back to the scale the pinch started from. Every update reapplied the zoom state, which a pinch doesn't change until it ends, so a change to the overlay's state while pinching zoomed a fitted image back out.
- An image with no size, such as an empty `UIImage`, no longer gives an infinite minimum zoom scale that was handed to the scroll view. Either the image or the frame having no width or height now leaves the zoom scale at 1.
- Dragging an image away no longer divides by zero when the drag has no length, which gave an offset of `NaN`. A vector with no length now normalizes to zero.
- Replacing the image without setting the binding to `nil` in between now shows the new image immediately, with no transition, in a new scroll view at its own size and zoomed out. Presenting an image when there is nothing on screen still fades in, and dismissing one still fades out. Previously the new image was swapped into the scroll view already on screen, which kept the frame it was built with, so an image of a different size was stretched to fit the previous one's frame.

### Removed

- Unused internal `Shape.scaleToFit(_:aspectRatio:)` extension.
- `Comparable` conformance on the internal `ZoomState`. Its ordering was equality in disguise, so `.min` compared as less than itself and the zoomed in, out and partial states did not order against each other at all. Nothing used the ordering, so it is now just `Equatable`.

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
