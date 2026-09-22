# ZoomImageViewer as Fullscreen Cover

Status: Revised proposal for review; no implementation has started.

Scope: Present the viewer above a partial-height SwiftUI sheet while retaining iOS 15 support. This proposal changes viewer placement; passing source information for thumbnail matching is a separate, optional stage.

## Core problem and decision

The current `zoomImageViewer` modifier inserts `ZoomImageViewerHost` as an overlay on the modified view. An overlay outside a sheet stays behind the sheet. An overlay inside a medium-height sheet is limited to that sheet's bounds. Environment values, preferences, and a portal that only passes information cannot change either fact.

The viewer itself must become the **content of a `fullScreenCover` presented from the current presentation**. A presenter attached to ordinary content can open the cover when no sheet is showing. A small portal attached inside a sheet installs another cover presenter there. When the sheet portal is active, it owns the cover and the outer presenter stays inactive. The portal is a placement helper, not a second image viewer or merely a source-information bridge.

This design uses SwiftUI's `fullScreenCover` on iOS 15 and later. It does not depend on a separate `UIWindow`, UIKit `overFullScreen` presentation, or a newer SwiftUI transition API. If the native cover's motion is unacceptable, that is a limitation of this cover-only proposal rather than a reason to silently change its presentation mechanism.

## Proposed call site

```swift
@State private var selectedPhoto: Photo?
@State private var showSheet = false

var body: some View {
    RootContent()
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                SheetGallery(selectedPhoto: $selectedPhoto)
            }
            .zoomImageViewerPortal()
        }
        .zoomImageViewer(item: $selectedPhoto, image: \.image) { photo in
            ZoomImageDefaultOverlay()
            Text(photo.caption)
        }
}
```

`zoomImageViewerPortal()` is a proposed, opt-in public modifier. The caller continues to declare the selection, image key path, wrapper, and overlay once. The sheet receives that configuration through the enclosing viewer scope. The example uses `NavigationStack` on iOS 16 and later; an iOS 15 example needs an available navigation container or no navigation.

The same mechanism applies to `zoomImageViewer(uiImage:)`. No source ID is needed for that overload.

## How the cover is placed

The outer `zoomImageViewer` modifier owns one stable viewer scope and installs a root cover presenter. It passes the scope down through the environment. The sheet portal reads that scope and installs a `fullScreenCover` **on the sheet's content**, outside the sheet's navigation container:

```swift
// Conceptual portal implementation; names are provisional.
sheetContent
    .fullScreenCover(isPresented: portalCoverBinding) {
        ZoomImageViewerHost(
            uiImage: scope.imageBinding,
            dismissAction: scope.dismissAction,
            overlay: scope.currentOverlay,
            matchedGeometry: nil,
            reduceMotionAtInsertion: scope.reduceMotion
        )
    }
```

The host above is the fullscreen cover's content. It is not also drawn as an overlay inside or outside the sheet. SwiftUI owns the modal z-order and gives the cover the presentation's full screen, regardless of the sheet detent. On close, the cover disappears and the same sheet remains underneath. The root presenter uses the same cover-backed viewer when no portal owns the selection.

This placement is the first proof required. An example-app prototype must show a medium-detent sheet, open the sheet-local cover, and confirm that the image is above the sheet, fills the scene's window, and returns to the same sheet and detent. SwiftUI's `presentationDetents` begins in iOS 16, so the medium-detent example needs an availability branch. On iOS 15, verify the cover above an available partial-size presentation, such as a UIKit `UISheetPresentationController` at `.medium` or an iPad form sheet. If that fails, the portal approach fails before any source-matching work begins.

## Inputs shared with the sheet

The portal needs only the data required to show and dismiss the viewer: the normalized selected image, the external item or image binding, the already-built overlay view, the dismiss action, the optional wrapper, and the active presenter identity. The viewer modifier supplies these through a scope visible to its sheet descendants. A package-owned `ObservableObject` can hold stable routing state on iOS 15; immutable/current view inputs can be passed through the environment without storing a newly created overlay closure there.

`ZoomImageItemOverlay` currently builds content while the modified view updates and retains the latest item through dismissal. Moving the host into a cover must preserve both behaviors. The portal boundary may need type erasure of the already-built overlay view. Verify that parent state captured by custom overlay content still updates while the cover is shown.

The first implementation does **not** send `ZoomImageSourceIDs`, source frames, or a matched-geometry namespace across the sheet boundary. With no source match, `.zoomImageSource(id:)` must leave the sheet thumbnail visible; today's source-hiding logic must not hide it merely because its ID equals the selected item.

## One presentation owner and cover lifetime

One scope has at most one active cover presenter. A portal registers while its sheet exists; otherwise the root presenter is eligible. Choosing an owner and turning on its cover happen as one coordinated selection change, so the root cannot briefly present a second cover behind the sheet. Once a cover opens, its owner stays fixed until that cover is gone. A new item replaces the image inside the existing cover rather than dismissing and reopening it.

Use a separate cover-presentation state instead of tying `fullScreenCover(isPresented:)` directly to `selectedPhoto != nil`. The current host retains an image after the external binding becomes `nil`, and a drag dismissal can animate before cleanup. The cover must remain mounted for whatever part of that sequence this design keeps. A cover teardown must be keyed to the active presentation identity so an old completion cannot close a replacement.

If the sheet disappears externally while its cover is active, clear that viewer selection and retire the sheet-owned cover. Do not transfer the displayed image to the root presenter or resurrect it behind the sheet. The first version supports one live portal per viewer scope; nested presentations need an explicit owner policy before support is claimed. Scope ownership remains scene-local, with no application-global singleton.

## iOS 15 animation constraint

Moving the viewer from an in-hierarchy overlay to a native cover changes the transition boundary. `fullScreenCover` supplies its own presentation and dismissal motion. The current matched-source transition depends on inserting/removing source and image in a coordinated SwiftUI transaction; it must not be assumed to work across the new cover. Even the current internal fade and toss can conflict with a second cover animation.

The iOS 15 baseline is therefore a **cover-backed viewer without thumbnail matching**. Its initial content should be fully laid out and opaque before the system reveals the cover; it must not flash a default hosting background or play a second entrance fade. Closing via the button, escape action, or external binding should produce one coherent cover dismissal. A drag dismissal may animate the image within the cover, then dismiss the cover, but that two-stage result needs visual approval. Immediate item replacement, zoom, pan, overlay content, and accessibility remain required.

This is a material change from the current source-growth and fade behavior, even outside sheets if the root presenter also becomes cover-backed. The spec does not claim animation parity. If parity is required on iOS 15, a cover-only design may not satisfy it; the example-app prototype must establish the actual tradeoff before implementation is approved.

`presentationBackground(_:)` begins in iOS 16.4 and cannot be the iOS 15 solution for a transparent cover. `navigationTransition(_:)` begins in iOS 18 and cannot supply the iOS 15 matching path. The proposal does not rely on either API. It also does not assume that setting a transaction's animation to `nil` removes the system's cover motion.

## Optional later source matching

Only after cover placement and baseline interaction are validated should the package consider thumbnail matching. That stage would need sheet-local source discovery, a shared identifier/namespace or explicit window-coordinate source frame, and a tested transition across the sheet and cover presentation roots. IDs alone would only tell the viewer which thumbnail is selected; they would not animate its geometry. If no reliable iOS 15 match is possible, portal presentations should continue to use the documented cover transition while ordinary non-portal presentations could retain their existing overlay path if the overall migration scope is narrowed.

## Implementation sequence

1. Create an isolated example-app spike with a medium-detent sheet and a `fullScreenCover` attached inside it. Use SwiftUI detents on iOS 16+ and an available partial-size presentation on iOS 15. Verify placement, sheet restoration, background appearance, and system motion before adding any coordinator.
2. Decide whether cover placement applies to every `zoomImageViewer` or only to portal presentations. The proposed architecture uses covers for both; preserving the current overlay path outside sheets is a narrower alternative if its matched transition cannot be retained in a cover.
3. Introduce one viewer scope and portal registration. Route selection to exactly one cover presenter and keep its identity through replacement and dismissal.
4. Adapt `ZoomImageViewerHost` for cover ownership and choose one animation authority for each entrance and exit. Preserve close, drag, zoom, overlay, wrapper, and accessibility behavior where compatible; document visual changes.
5. Add an example sheet and focused tests for routing, replacement, dismissal cleanup, sheet disappearance, and overlay updates. Treat matched source motion as a separate stage.

## Acceptance criteria

- On iOS 16+ and a current iOS version, selecting an image inside a medium-detent sheet presents the viewer above the sheet at the scene's full size, then returns to the same sheet without changing its detent. On iOS 15, the same placement works above an available partial-size modal presentation.
- No viewer is rendered behind the sheet and no duplicate cover opens. Replacement does not dismiss and reopen the cover.
- Close, escape, external binding clear, and drag dismissal leave the binding and cover in a consistent state; late cleanup cannot close a replacement.
- Custom overlay updates, the default close button, wrapper rotation, zoom/pan, VoiceOver modal behavior, and system chrome are checked in the cover, including on iOS 15.
- The first release makes no claim of source-matched animation inside sheets. A source remains visible during a non-matched portal presentation.
- Existing non-sheet behavior is either preserved or its cover-related visual changes are explicitly approved. Automated builds/tests are followed by simulator or device interaction; compilation alone cannot establish modal animation quality.

## Review decisions

1. Should every viewer move to `fullScreenCover`, accepting that the root viewer's current matched-source transition may change, or should only portal presentations use a cover?
2. Is the native cover presentation/dismissal motion acceptable on iOS 15, including its interaction with drag-to-dismiss, or is preserving the current fade/matched motion a requirement?
3. Is one live portal per viewer scope sufficient initially?

## Platform references

- [SwiftUI fullScreenCover](https://developer.apple.com/documentation/swiftui/view/fullscreencover%28ispresented%3Aondismiss%3Acontent%3A%29) for the fullscreen presentation itself.
- [SwiftUI iOS 16.4 presentation background](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-16_4-release-notes) and [SwiftUI navigation transition](https://developer.apple.com/documentation/swiftui/view/navigationtransition%28_%3A%29) for APIs unavailable at the package's iOS 15 minimum.
- [SwiftUI matchedGeometryEffect](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect%28id%3Ain%3Aproperties%3Aanchor%3Aissource%3A%29) for the current source-match requirements.
