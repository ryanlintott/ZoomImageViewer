# Changelog

## Unreleased

### Breaking Changes

- Raised the minimum supported iOS version from 14 to 15.
- Raised the Swift tools version to 6.0. The package now builds in the Swift 6 language mode and needs Swift 6.0 or later.

### Added

- Shared `ZoomImageViewer.xcworkspace` and `ZoomImageViewer Development` scheme for package and example-app development.
- Swift Package Index configuration for building and hosting the package's documentation.
- GitHub Actions workflow testing Swift 6.0 compatibility and building and testing on iOS with the current Swift version.
- This changelog.
- Unit tests for `ScaleToFitPadding`, the shape used to block gestures in the empty space around a scaled image, and for `CGSize.scaledToFit(_:)`.
- Unit tests for the zoom scale limits.

### Changed

- Presenting an image always starts zoomed out and interactive rather than inheriting the zoom state of a previous one.
- Rewrote the readme with badges, installation steps, and examples for each feature.
- The example app's minimum deployment target is now iOS 15, matching the package. Xcode 26 no longer builds for iOS 14, so the example app would not compile.
- The example app's local package reference now points at `..` instead of `../../ZoomImageViewer`, so it no longer depends on the name of the folder containing the repository.
- Tests now use Swift Testing instead of XCTest.

### Fixed

- Zooming, double tap and drag to dismiss no longer stop working when the image has the same aspect ratio as the screen, such as a screenshot taken on the same device. The shape blocking gestures in the empty space around the image covered the whole screen in that case.
- Images smaller than the screen now fill it and can be zoomed. They need a zoom scale above 1 just to fit, which was larger than the maximum zoom scale, so they rendered small and would not zoom at all. The maximum zoom scale is now never below the scale needed to fit, and allows zooming to twice that. Images at least as large as the screen are unaffected.
- Pinch zooming no longer centres the image against the frame size from when it first appeared. The scroll view delegate held the first version of the view it was given, so after a rotation or a window resize it inset the image using the old size.
- Replacing the image without setting the binding to `nil` in between is now presented as a dismissal followed by a fresh presentation. The old image fades out, the new one fades in, and it is shown by a new scroll view at its own size, zoomed out. Previously the new image was swapped into the scroll view already on screen, which kept the frame it was built with, so an image of a different size was stretched to fit the previous one's frame.

### Removed

- Unused internal `Shape.scaleToFit(_:aspectRatio:)` extension.

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
