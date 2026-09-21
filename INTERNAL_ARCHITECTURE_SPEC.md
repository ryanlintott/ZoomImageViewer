# ZoomImageViewer Internal Architecture

Status: Implemented; awaiting code and visual review  
Scope: Internal simplification of the unreleased modifier-based viewer  
Public API impact: None proposed

## Summary

Keep the new modifier-based API and its current user-facing behavior, but reorganize the implementation around one explicit presentation state machine.

The refactor should separate four concerns that are currently interleaved:

1. Adapting the public `UIImage` and item APIs into one internal presentation input.
2. Discovering source views and deciding whether a transition can use matched geometry.
3. Owning the lifetime and interaction state of the presented image.
4. Rendering the viewer, its image, and its chrome from that state.

The source-view feature, wrapper feature, UIKit scroll view, matched-geometry motion, and accessibility behavior remain. The goal is not fewer features. The goal is fewer implicit states, one dismissal path, and transition decisions that cannot change halfway through an animation.

## Why this work is needed

The current implementation works by coordinating state across `ZoomImageViewerModifier`, `ZoomImageSourceModifier`, `ZoomImageItemOverlay`, and `_ZoomImageView`. `_ZoomImageView` alone owns the displayed image, retained matched geometry, interaction, zoom, chrome visibility, drag measurements, three opacities, accessibility requests, removal identity, presentation identity, and content rotation.

Several values describe different parts of the same lifecycle:

- `uiImage` and `displayedImage`
- `currentMatchedGeometry` and `displayedMatchedGeometry`
- `removalID` and `presentationID`
- `isInteractive`, `isDragging`, and drag data
- `backgroundOpacity`, `imageOpacity`, and `overlayOpacity`
- `isShowingOverlay`, `isZoomedIn`, and `isShowingSystemOverlay`

Those values are individually reasonable, but valid combinations are enforced by ordering, comments, and early returns rather than by a single model. The meaning of `matchedGeometry == nil` also changes with the binding, source visibility, Reduce Motion, and removal progress. As features accumulate, it becomes harder to prove that a new event cannot create an invalid combination.

The automatic source discovery is necessarily more sophisticated than the old explicit namespace API. It is not the first target for removal: the environment selects the nearest compatible viewer, and the preference reports which lazy sources are actually on screen. That mechanism should instead become a narrow input to the presentation state machine.

## Goals

- Preserve the current modifier-based public API and documented behavior.
- Make every presentation and dismissal representable by an explicit state.
- Route close button, escape, binding changes, and drag dismissal through one lifecycle path.
- Decide and retain an opening or dismissal transition when that transition begins.
- Make replacement, cancellation, and stale cleanup behavior deterministic.
- Separate state transitions from SwiftUI rendering so the lifecycle can be unit tested.
- Keep matched geometry responsible for geometry only; retain the independent offset and rotation transition needed for a tossed image to land smoothly.
- Keep the UIKit scroll view focused on zooming, panning, and accessibility scrolling.
- Make future behavior changes local: a new transition should not require adding flags throughout the view.

## Non-goals

- Removing source transitions, item presentation, custom overlays, or viewer wrappers.
- Replacing `UIScrollView` with a SwiftUI-only zoom implementation.
- Changing the spring, toss, fade, or chrome timing as part of the refactor.
- Solving cropped-thumbnail matching.
- Expanding the existing rotation work beyond behavior already documented by the package.
- Adding a public configuration object or exposing internal animation controls.
- Removing deprecated `ZoomImageView` APIs before a separately planned major release.
- Rewriting source discovery merely to reduce line count.

## Public behavior contract

The refactor is complete only if these behaviors remain true.

| Event | Source available | No source available | Reduce Motion |
| --- | --- | --- | --- |
| Present | Grow from the source with the viewer spring | Fade in | Fade in; source remains visible |
| Close button, escape, or binding cleared | Shrink to the source | Fade out | Fade out |
| Drag past dismissal threshold | Continue from release velocity and land on the source | Toss off screen while fading | Toss off screen while fading |
| Drag below threshold | Return to the fitted position and restore chrome | Same | Same, without unnecessary large motion |
| Replace the value while open | Replace immediately, reset zoom/drag/chrome, and use the new item's source for a later close | Same immediate replacement | Same immediate replacement |
| Present while a dismissal is running | Cancel obsolete cleanup and show the latest value | Same | Same |

Additional invariants:

- `nil` means no requested presentation. Closing writes `nil` to the original image or item binding.
- A matched transition is used only when the selected item's source is currently on screen.
- Source views preserve layout and local state. Their visible content is hidden only while their item is represented by a matched fullscreen image.
- An overlay is built in the caller's update context, receives the value on screen, and retains the last value while dismissal finishes.
- Replacing an item without changing its image instance updates overlay content without resetting the image presentation.
- Replacing the `UIImage` instance resets zoom and drag state even if the item identifier is unchanged.
- The image ignores the safe area; the overlay respects it.
- The viewer uses a dark color scheme and a black semantic background.
- A wrapper affects the viewer below it, and a nearer wrapper replaces an outer wrapper.
- A view hierarchy containing source views has one viewer. Every source uses the same item representation as that viewer, including the corresponding wrapper-enum case when it presents several kinds of item.
- VoiceOver modal behavior, focus movement, zoom, scroll, escape, and overlay actions remain available.
- Voice Control input labels and localized built-in controls remain unchanged.

## Transition decisions

An animation must not change kind after it begins.

Opening and dismissal each create a `TransitionPlan` with one of these styles:

```swift
enum ZoomImageTransitionStyle {
    case fade
    case matched(ZoomImageMatchedGeometry)
    case toss(DismissToss)
}
```

The actual type may differ, but it must preserve these rules:

- Opening chooses `.matched` only when a source is on screen and Reduce Motion is off at the moment presentation begins.
- Programmatic dismissal chooses `.matched` only when a source is on screen and Reduce Motion is off at the moment dismissal begins.
- Drag dismissal chooses `.matched` under the same conditions; otherwise it chooses `.toss`.
- A matched drag dismissal stores the release offset, release velocity, content rotation, and matched geometry in its plan.
- A running transition keeps its plan even if the source scrolls away, Reduce Motion changes, or the binding changes afterward.
- A later transition evaluates the latest source availability and accessibility setting again.

This deliberately defines behavior that is currently implicit: changing Reduce Motion or source availability does not switch an animation already in flight to a different rendering path.

## State model

The viewer should have one authoritative `ZoomImagePresentationState`, stored in one `@State` property. It may contain nested value types, but the view should not mirror lifecycle facts in independent properties.

```swift
struct ZoomImagePresentationState<Value> {
    var lifecycle: Lifecycle<Value> = .idle
    var zoom: ZoomState = .min
    var chrome: ChromeVisibility = .shown
    var drag: DragState?
    var accessibilityScrollRequest: AccessibilityScrollRequest?
}

enum Lifecycle<Value> {
    case idle
    case presented(Session<Value>)
    case dismissing(Session<Value>, Dismissal)
}
```

`Session` is the stable snapshot for the value currently being rendered. It includes:

- A unique session identifier.
- The presented value or the minimum snapshot required to rebuild its overlay.
- The `UIImage` and its `ObjectIdentifier`.
- The source identifier, when the public API is item-based.
- The opening transition plan.

`Dismissal` includes:

- A unique dismissal identifier used to reject stale completions.
- The latched transition plan.
- Any drag offset and velocity needed by that plan.
- The duration after which the session can be removed.

The exact nesting is an implementation detail. These constraints are not:

- `idle` has no rendered image and no pending cleanup.
- `presented` has exactly one session and no dismissal plan.
- `dismissing` retains exactly one session and exactly one immutable dismissal plan.
- A drag can exist only for the active session.
- A cleanup completion is accepted only when its dismissal identifier is still current.
- Image, background, overlay, interaction, and source visibility are derived from the state; they are not separate authorities for the lifecycle.

## Events and transitions

All lifecycle changes go through named methods on the state type or a small reducer. Rendering code must not directly assemble partial lifecycle state.

| Current state | Event | Result |
| --- | --- | --- |
| `idle` | Non-`nil` input | Create a session and enter `presented` with a latched opening plan |
| `idle` | `nil` input | No change |
| `presented` | Same value and same image identity updated | Refresh current metadata/overlay input without resetting interaction |
| `presented` | Different image identity | Replace the session immediately and reset zoom, drag, chrome, and accessibility scroll state |
| `presented` | Close request or input becomes `nil` | Create one dismissal plan and enter `dismissing` |
| `presented` | Drag changes | Update the session's drag state and derived background visibility |
| `presented` | Drag ends below threshold | Clear drag state and restore the fitted presentation |
| `presented` | Drag ends above threshold | Create one dismissal plan, enter `dismissing`, then clear the external binding |
| `dismissing` | A non-`nil` input arrives | Invalidate the old dismissal and present the latest session |
| `dismissing` | Matching cleanup completes | Enter `idle` and clear retained session data |
| `dismissing` | Stale cleanup completes | Ignore it |
| Any state | Source availability changes | Update transition capability for the next transition; never rewrite a running plan |

Closing from the close action or escape gesture should clear the external binding. The resulting input change then enters dismissal through the same event used when the caller clears the binding. Drag dismissal may enter `dismissing` before it writes `nil`, because its release data must be captured first; the subsequent `nil` event must be idempotent.

## Derived presentation properties

The renderer should read named derived properties rather than reproduce lifecycle conditions in view modifiers:

- `renderedImage`
- `imageIdentity`
- `isCanvasInHierarchy`
- `isViewerVisible`
- `isScrollInteractionEnabled`
- `imageOffset`
- `backgroundOpacityTarget`
- `imageOpacityTarget`
- `overlayOpacityTarget`
- `isOverlayAccessible`
- `areSystemOverlaysVisible`
- `imageTransition`
- `removalDelay`

For example, a matched dismissal removes the fullscreen canvas in the binding transaction while retaining the session long enough to render the fading background and overlay. A fade or toss dismissal keeps the canvas until cleanup. That distinction belongs in the dismissal plan, not in a repeated `matchedGeometry == nil` test.

## Internal boundaries

### 1. Public API adapters

`ZoomImageViewerModifier.swift` should contain the public overloads and documentation. Each overload normalizes its inputs for the host:

- The current optional value.
- The current image and its identity.
- The current source identifier, if any.
- The eagerly built current overlay content, so SwiftUI observes state captured by the builder in the caller's update context.
- The original binding used for dismissal.

The item form keeps a projected `Binding<UIImage?>` as a live SwiftUI dependency at the preference-overlay and host boundary. Matched insertion must observe the image in the same transaction that removes the source stand-in; a captured image value reaches that overlay too late. The original item binding remains the dismissal target, while the image, item identifier, and overlay input still come from the same item update.

The existing retained-overlay behavior may remain a dedicated helper. It must not move an escaping builder into a deferred child context that loses SwiftUI dependency tracking.

### 2. Source registry

`ZoomImageSourceModifier` remains responsible for:

- Reading the viewer above it through the environment.
- Reporting its on-screen identifier through a preference.
- Supplying the matched-geometry stand-in.
- Hiding and restoring source content at the viewer's established timing.

The viewer host converts the registry result into a simple `SourceAvailability` value. The presentation state does not read preferences or environment values directly.

`ZoomImageSourceID` combines the item type with its type-erased identifier, preventing unrelated items with equal raw identifiers from colliding. Both matched-geometry endpoints use that same concrete wrapper type.

### 3. Presentation state

Add a pure value type, tentatively `ZoomImagePresentationState`, in its own file. It owns lifecycle and interaction transitions but imports no UIKit view types. Pure calculations such as event handling, dismissal eligibility, stale-completion rejection, and derived visibility should be testable without rendering a SwiftUI hierarchy.

Animation APIs such as `withAnimation` remain in the renderer or host. The state chooses the semantic transition and target values; the view applies the animation transaction.

The state update that records a first presentation must inherit the transaction that inserts the matched destination and removes its source. Animations may be disabled around an immediate replacement, but not around first presentation; a second nonanimated first-presentation update interrupts matched geometry before it reaches fullscreen.

### 4. Viewer host

Add a small host view responsible for:

- Reconciling normalized public input with presentation state.
- Resolving the current source availability into transition capability.
- Starting the one cleanup task keyed by dismissal identity.
- Writing `nil` to the external binding for user-initiated closes.
- Passing derived state and actions to the renderer.

The host must be the only owner of delayed removal. A new presentation cancels the old task by changing its task identity.

The image, newly resolved source geometry, and Reduce Motion value must be observed as one coherent request. A one-parameter `onChange` closure sees the view from before the change, so reading a stored view input such as the source geometry from inside that closure can combine the new image with the preceding render's source state.

### 5. Renderer

Split the current `_ZoomImageView` composition into focused views:

- `ZoomImageViewerScreen`: background, safe-area policy, overlay, system chrome, modal accessibility, and focus notifications.
- `ZoomImageCanvas`: image scroll view, image identity, matched geometry, drag gesture, image accessibility, and image transition.

The names are provisional. The responsibility split is required. Neither view should own a second copy of presentation lifecycle state.

`ZoomImageViewRepresentable` and `ZoomImageScrollView` remain responsible for UIKit zoom and pan behavior. Their bindings and callbacks should describe events (`zoomChanged`, `overlayShouldHide`, `scrollRequestHandled`) rather than mutate unrelated lifecycle state.

### 6. Transition helpers

Keep mathematical and rendering details outside the lifecycle model:

- `DismissToss` computes an off-screen toss.
- `ZoomImageMatchedGeometry` computes landing animation and transition modifiers.
- `ZoomImageContentRotation` measures and corrects wrapper rotation.

Matched geometry continues to handle frame interpolation only. The offset and rotation correction remains a separate transition so a dragged image preserves its release motion and lands square with its source.

### 7. Wrapper boundary

Keep wrapper type erasure isolated to `ZoomImageViewerWrapper`. The environment cannot store an arbitrary generic wrapper type, so `AnyView` is justified at this boundary. It should not spread into the presentation state or normal renderer composition.

## Proposed file layout

The final names can change during review, but each type should have one clear responsibility.

```text
Sources/ZoomImageViewer/
  ZoomImageViewerModifier.swift       Public modifier overloads only
  ZoomImageViewerHost.swift           Input reconciliation and effects
  ZoomImagePresentationRequest.swift Coherent external transition input
  ZoomImagePresentationState.swift    Pure lifecycle and interaction state
  ZoomImageTransitionPlan.swift       Latched semantic transition data
  ZoomImageViewerScreen.swift         Background, overlay, system UI, modal shell
  ZoomImageCanvas.swift               Image, gestures, accessibility, transition
  ZoomImageSource.swift               Public source API
  ZoomImageSourceModifier.swift       Source environment/preference bridge
  ZoomImageViewerWrapper.swift        Wrapper API and isolated type erasure
  ZoomImageMatchedGeometry.swift      Matched motion and modifiers
  DismissToss.swift                   Toss calculation
```

This is a responsibility map, not a requirement to split tiny helpers mechanically. Existing public types may stay in their current files when moving them would add churn without improving ownership.

## Complexity rules

The refactor should satisfy these rules rather than merely reduce line count:

1. There is one authoritative presentation state property.
2. There is one method that begins dismissal and one cleanup effect that ends it.
3. A transition style is immutable after its plan is created.
4. No boolean independently duplicates a lifecycle phase.
5. No opacity independently decides whether a session exists.
6. Source discovery does not mutate presentation state directly; it emits availability.
7. The renderer does not write the external binding except through a host action.
8. A stale timer or task cannot remove a newer session.
9. Views do not perform lifecycle decisions inline in `body`.
10. Type erasure is confined to boundaries that require it.
11. First presentation is never reconciled inside a transaction with animations disabled; only an actual replacement may opt out of animation.

## Testing strategy

Use Swift Testing for new unit and integration tests. Keep UI automation in XCTest if UI tests are added.

### State tests

Add table-driven tests for every row in the event table, including:

- First presentation.
- Repeated identical input.
- Same item identifier with updated metadata.
- Same item identifier with a new image instance.
- Immediate replacement while visible.
- Replacement during fade, toss, and matched dismissal.
- Close request followed by the binding's `nil` update.
- Drag cancellation and drag dismissal.
- Stale cleanup after a newer session begins.
- Source appearing or disappearing before dismissal.
- Source changing after dismissal begins.
- Reduce Motion changing before and after a transition plan is created.

### Existing helper tests

Retain the geometry, zoom scale, content inset, accessibility scroll, toss, content rotation, and landing-speed tests. Move only tests whose subject moves.

### Integration and visual verification

The example app is the interaction harness. Verify at least:

- Plain image fade open, close, toss, and interrupted dismissal.
- Item open and close with a visible source.
- Item with an off-screen source.
- Source scrolling on or off screen before close.
- Stepping between images, including during dismissal.
- Close button and accessibility escape.
- Portrait matched toss with slow and fast release velocities.
- Reduce Motion for source and non-source presentations.
- VoiceOver focus, image label, zoom, scroll, and controls action.
- Voice Control labels.
- Wrapper rotation behavior already supported by the example.

Build and unit tests are necessary but do not establish that gesture-to-transition continuity looks correct. Matched transitions and tosses require simulator or device interaction verification before the refactor is considered complete.

### Public API verification

- Build the package and run its test suite.
- Build the checked-in example workspace and `ZoomImageViewer Development` scheme.
- Build DocC documentation.
- Compile an external-client fixture that imports the library and exercises every public modifier overload, the wrapper, source modifier, overlay components, close action, and deprecated compatibility initializers.

## Implementation sequence

Each stage should be reviewable and leave the package building.

1. Add characterization tests for lifecycle edges without changing behavior.
2. Introduce `ZoomImagePresentationState` and transition-plan tests.
3. Route current rendering through the new state while keeping the existing view structure.
4. Move binding reconciliation and delayed cleanup into the host.
5. Extract the screen and canvas renderers.
6. Normalize item input so the item, image, source identifier, overlay, and dismissal binding share one snapshot.
7. Split source and wrapper internals into their final boundaries if the earlier stages show that the split improves clarity.
8. Remove obsolete mirrored state and compatibility helpers made unnecessary by the new model.
9. Run the full build, test, DocC, external-client, accessibility, and visual verification matrix.

Avoid mixing animation retuning or public API redesign into these stages. A behavior change discovered to be necessary should become a separate reviewed amendment to this spec.

## Acceptance criteria

- All public behavior in this document is preserved.
- No public source break is introduced beyond deprecations already present on the branch.
- The viewer has one authoritative lifecycle model and no independently mutable lifecycle flags.
- Every close mechanism reaches the same dismissal transition.
- Every running animation has a latched transition plan.
- Replacement during dismissal cannot be removed by obsolete cleanup.
- Source visibility and Reduce Motion changes affect only transitions that have not started.
- Source matching still uses the concrete identifier type.
- Overlay content stays current and remains visible through dismissal.
- The package, example, DocC, and external-client fixture build successfully.
- Unit tests pass, and the visual/accessibility matrix is completed on the current checkout.

## Review questions

## Approved decisions

1. A source that scrolls on screen while the viewer is open becomes eligible if it is available when dismissal begins.
2. Programmatic removal of a source after matched dismissal begins is unsupported. The transition remains latched and the implementation does not retain off-screen lazy content.
3. A Reduce Motion change applies when the next transition begins, not to one already in flight.
4. Replacement while open remains immediate. A replacement transition may be considered separately only if the new architecture makes it trivial and does not complicate the lifecycle.
5. `zoomImageViewerWrapper(_:)` remains public so clients can add `AutoRotatingView` from FrameUp. Its environment boundary requires type erasure; keep that erasure isolated and document it rather than removing the feature.
6. Deprecated `ZoomImageView` initializers remain for now.
