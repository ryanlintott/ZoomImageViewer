# ZoomImageViewer Host Simplification

Status: Implemented. See [Implementation notes](#implementation-notes) for where the code differs from this proposal.

Scope: Internal refactor of `ZoomImageViewerHost`, `ZoomImagePresentationState`, `ZoomImageCanvas`, and `ZoomImageViewerScreen`

Public API impact: None proposed

## Summary

Simplify the viewer implementation by returning to the directness of `_ZoomImageView` without putting all rendering and interaction code back into one type.

The viewer will still have one shared `ZoomImagePresentationState`, but that state will be shallow. `ZoomImageCanvas` and `ZoomImageViewerScreen` will receive it directly instead of receiving a long list of values and callbacks. Lifecycle changes will be visible where they happen rather than hidden behind a vocabulary of state-machine commands such as `present`, `finishOpening`, `beginDismissal`, and `finishDismissal`.

Reusable calculations and mechanical operations should live on the small types that understand them. For example, a transition should answer whether it has matched geometry and how long its removal takes, and `DismissToss` should continue to calculate its own destination and animation. The main views should coordinate these helpers rather than contain long mathematical or translation functions.

This is a simplification refactor, not an attempt to preserve every internal edge-case distinction in the current state machine. The visible viewer behavior should remain the same.

## Motivation

The current architecture successfully gives presentation lifetime one owner, but it introduces more conceptual layers than the viewer needs:

```text
ZoomImagePresentationState
  Lifecycle
    Session
      OpeningStyle
    Dismissal
      Style
  Drag
  Appearance
```

That hierarchy makes ordinary questions difficult to answer from the call site:

- Is `present` used only for a first presentation, or also for replacement and cancellation?
- Does `finishOpening` change anything visible, or only which source geometry is consulted?
- Must `beginDismissal` be paired with `finishDismissal`, and who owns that pairing?
- Which values are reset by a replacement, a cancelled dismissal, and final cleanup?
- Does rendering use the session, the dismissal, the external binding, or a mixture of them?

At the same time, extracting the canvas and screen made their initializers describe nearly every implementation detail. That moved lines out of the host without making the overall data flow easier to follow.

The target design should make the sequence readable directly:

1. A coherent external request arrives.
2. The host updates a few shallow presentation fields.
3. The canvas mutates interaction fields while the person interacts with the image.
4. The screen renders chrome and presentation appearance from the same state.
5. A task keyed to the current phase removes an image after dismissal.

## Goals

- Keep one authoritative presentation state.
- Replace the nested session, dismissal, drag, and appearance containers with direct stored properties.
- Keep at most one small lifecycle enum.
- Let the canvas and screen work with presentation state directly.
- Remove the large canvas and screen initializer surfaces.
- Make lifecycle mutations visible in the host instead of hiding them behind state-machine commands.
- Put reusable calculations and mechanical transformations on the helper types that understand them.
- Keep `body` implementations declarative and short.
- Preserve the current visible presentation, replacement, dismissal, drag, zoom, matched-geometry, Reduce Motion, overlay, and accessibility behavior.
- Permit simpler internal handling of interrupted and unusual sequences when the UI result is unchanged.

## Non-goals

- Changing the public `zoomImageViewer` or `zoomImageSource` APIs.
- Removing `ZoomImageCanvas` or `ZoomImageViewerScreen`.
- Returning to a single `_ZoomImageView` containing all modifiers and gesture code.
- Introducing a reducer, event protocol, coordinator object, view model, or general-purpose configuration layer.
- Making the presentation state enforce every valid combination through its type system.
- Retuning animations or changing the normal visual behavior.
- Reworking source discovery, wrappers, or the UIKit zoom implementation except where their inputs become simpler.
- Preserving internal names, nesting, or transition distinctions solely because the current implementation has them.

## Design principles

### Prefer visible coordination over encoded lifecycle commands

The host may directly assign `phase`, `image`, transition, identity, and resettable interaction values. The important sequence should be readable in the function reacting to the external request.

There should not be a second API that requires a reader to learn when to call `present`, `finishOpening`, `beginDismissal`, `prepareCanvasAfterMatchedRemoval`, and `finishDismissal`.

Small mechanical helpers remain appropriate when their effect is complete and unsurprising. Resetting all interaction fields to their defaults is one such operation. Starting or completing a lifecycle phase is not: those assignments should remain visible at the coordinating call site.

### Give operations to the type that has the knowledge

Helper methods should express generally reusable knowledge, not merely move host code elsewhere.

Examples:

- A transition can expose its matched geometry, whether it keeps the image in the hierarchy, and its cleanup delay.
- `DismissToss` owns toss destination and animation calculations.
- `ZoomImageMatchedGeometry` owns its image transition and landing-speed calculation.
- `AccessibilityScrollRequest` can translate an accessibility edge and layout direction into the UIKit edge it stores.
- Presentation state can expose derived rendering facts and perform a complete mechanical interaction reset.

Avoid extensions whose only purpose is to split `ZoomImageViewerHost` across files. In particular, the target is not a collection of large `extension ZoomImageViewerHost` blocks named Presentation, Drag, or Accessibility.

### Share state without obscuring write ownership

Passing presentation state directly is intentional. These are private implementation views representing different parts of one viewer, so a narrowly decoupled callback interface is not worth dozens of forwarded properties and closures.

The state remains owned by the host. Child views receive either a binding or a value according to whether they need to mutate it. Their allowed writes are documented below so shared access does not become uncontrolled ownership.

## Proposed state model

The exact spelling can change during implementation, but the shape should remain shallow:

```swift
struct ZoomImagePresentationState {
    enum Phase {
        case hidden
        case appearing
        case presented
        case dismissing
    }

    var phase: Phase = .hidden
    var phaseID = UUID()

    var image: UIImage?
    var availableMatchedGeometry: ZoomImageMatchedGeometry?
    var transition: ZoomImagePresentationTransition = .fade
    var canvasID = UUID()

    var zoomState: ZoomState = .min
    var isZoomedIn = false
    var isShowingOverlay = true
    var isInteractive = true

    var dragOffset: CGSize = .zero
    var predictedEndTranslation: CGSize = .zero
    var dragVelocity: CGSize?

    var backgroundOpacity: Double = 0
    var imageOpacity: Double = 0
    var overlayOpacity: Double = 0

    var accessibilityScrollRequest: AccessibilityScrollRequest?
}
```

This deliberately permits some temporary combinations that a deeply nested state machine could rule out. The viewer has a small number of mutation sites, all internal to the package, and readability is more valuable here than encoding every invariant in associated values.

`Phase` answers only where the presentation is in its visible lifetime:

- `hidden`: no retained image is rendered.
- `appearing`: the image has been inserted and its opening transition is settling.
- `presented`: the image is fully present and interactive.
- `dismissing`: the external value has been cleared or a drag dismissal has begun, but retained content may still be rendered.

`phaseID` identifies the current asynchronous phase. Changing it cancels a task keyed to the old value, and a completion checks the captured value before changing state. Separate session and dismissal identifiers are unnecessary.

## Transition model

Replace `Session.OpeningStyle` and `Dismissal.Style` with one small transition enum:

```swift
enum ZoomImagePresentationTransition {
    case fade
    case matched(ZoomImageMatchedGeometry)
    case toss(DismissToss)
}
```

The same type describes how the current phase moves. It should provide well-named derived operations such as:

```swift
var matchedGeometry: ZoomImageMatchedGeometry? { get }
var keepsImageDuringDismissal: Bool { get }
var settlingDuration: TimeInterval { get }

func imageTransition(
    rotation: ContentRotation,
    offset: CGSize,
    velocity: CGSize?
) -> AnyTransition
```

These properties remove repeated `switch` statements and `matchedGeometry == nil` tests from the views. They are appropriate abstraction because the answers follow from the transition itself.

The transition is latched while `phase` is `.appearing` or `.dismissing`. `availableMatchedGeometry` remains the latest source eligible for a future dismissal. A source or Reduce Motion change may affect the next transition, but does not rewrite one already in progress.

## Responsibility and write ownership

### `ZoomImageViewerHost`

The host owns the `@State` value and the external binding. It is responsible only for:

- Building the coherent `ZoomImagePresentationRequest`.
- Applying external image, source, and Reduce Motion changes.
- Directly assigning lifecycle fields for insertion, replacement, and dismissal.
- Clearing the external binding for a user-initiated dismissal.
- Running the task keyed by `phaseID` that moves `.appearing` to `.presented` or `.dismissing` to `.hidden`.
- Holding `ContentRotation`, which must be measured even while no image is present.
- Constructing the canvas and screen with the shared state.

The host should not own drag gesture handling, image accessibility actions, screen appearance modifiers, transition mathematics, or long groups of derived rendering properties.

Its lifecycle functions should be named after their input or effect rather than abstract state-machine commands. Expected examples are:

- `apply(_ request:)`
- `dismiss()`
- `completePhase(id:)`

`apply` may contain an explicit switch over `phase` and image identity. That local repetition is preferable to hiding the actual assignments behind several mutating methods and result enums.

### `ZoomImageCanvas`

The canvas receives a binding to the presentation state:

```swift
@Binding var presentation: ZoomImagePresentationState
```

It also receives only values that are genuinely outside that state, expected to be:

- Viewer size.
- Current content rotation, if needed to build the image transition.
- The action that clears the external presentation after a successful drag dismissal.

The canvas owns and directly updates:

- `zoomState` and `isZoomedIn` bindings passed to `ZoomImageViewRepresentable`.
- Overlay visibility changes caused by image interaction.
- Drag offset, prediction, and velocity.
- Interaction enablement during a drag.
- Background, image, and overlay opacity changes caused by dragging or tossing.
- Accessibility zoom and scroll requests for the image.
- The drag decision to return or dismiss.

General calculations should remain on helper types. The canvas coordinates them and applies animations; it should not contain the toss mathematics or matched-transition construction.

### `ZoomImageViewerScreen`

The screen also receives the presentation state directly. Use a binding if its appearance callbacks continue to set opacity fields; otherwise prefer a value.

It receives only:

- Presentation state.
- The canvas.
- The overlay.
- Viewer size, from which it can derive its rotating background size.
- The dismiss action used by escape and the overlay environment.

The screen derives from presentation state:

- Background, image, and overlay opacity.
- Whether overlay content is visible, interactive, and accessible.
- Whether system overlays are visible.
- Whether the screen uses an identity or opacity insertion transition.

The screen owns modal accessibility, focus notifications, safe-area composition, system-overlay modifiers, overlay styling, and initial/final appearance animation. These operations should no longer be callbacks supplied by the host.

### `ZoomImagePresentationState`

The state is data first. It may provide:

- Read-only rendering properties such as `renderedImage`, `isShowingImage`, `presentationOffset`, and `isShowingSystemOverlay`.
- A mechanical `resetInteraction()` that restores every interaction field together.
- A mechanical `resetAppearance()` if keeping the three scalar opacity assignments together is clearer.

It should not provide semantic lifecycle commands or return a `PresentationChange` result. The coordinating view should be able to see which fields an insertion, replacement, or dismissal changes.

## Expected view shape

The target is approximately this level of composition, not these exact signatures:

```swift
var body: some View {
    Color.clear.overlay {
        GeometryReader { proxy in
            let viewerSize = proxy.sizeIncludingSafeAreaInsets

            ContentRotationReader(rotation: $contentRotation)
                .ignoresSafeArea()

            if presentation.image != nil {
                ZoomImageViewerScreen(
                    presentation: $presentation,
                    canvas: ZoomImageCanvas(
                        presentation: $presentation,
                        viewerSize: viewerSize,
                        contentRotation: contentRotation,
                        dismiss: dismiss
                    ),
                    overlay: overlay,
                    viewerSize: viewerSize,
                    dismissAction: dismissAction
                )
            }
        }
        .onChange(of: request, perform: apply)
    }
    .task(id: presentation.phaseID) {
        await completeCurrentPhase()
    }
    .colorScheme(.dark)
}
```

The important result is that the host no longer constructs a canvas with a long list of mirrored values and event closures, and the screen no longer receives every visual decision as a separate property.

## Lifecycle behavior

### First presentation

When a non-`nil` image arrives while hidden, the host:

1. Stores the image and latest eligible source.
2. Chooses and stores `.matched` or `.fade` from the coherent request.
3. Resets interaction and appearance to their initial values.
4. Assigns a new `phaseID` and sets `phase` to `.appearing`.

The first matched update must remain in the caller's animated transaction. It must not be wrapped in `withoutAnimation`.

After the transition's settling duration, a matching phase task changes `.appearing` to `.presented`. This completion does not call a state command; it performs the small guarded assignment directly.

### Replacement

When a different `UIImage` instance arrives while an image is retained:

- Replace it immediately inside `withoutAnimation`.
- Reset interaction state.
- Keep the viewer's already visible appearance rather than replaying its fade.
- Store the latest eligible source for a future dismissal.
- Cancel obsolete phase work by changing `phaseID`.
- Announce the replacement when it has a non-empty accessibility label.

Replacement during dismissal follows the same path. It does not need separate `resumed` and `replacedDuringDismissal` result cases. The retained viewer simply becomes presented again, restores its visible appearance, and invalidates the old cleanup task.

### Programmatic dismissal

When the request image becomes `nil`, the host:

1. Ignores the update if already dismissing or hidden.
2. Chooses `.matched` from the retained eligible source, or `.fade` otherwise.
3. Stores the transition, assigns a new `phaseID`, and sets `phase` to `.dismissing`.
4. Starts the background, overlay, and, for a fade, image opacity animations.
5. Gives the next canvas a fresh identity when matched removal requires it.

After the stored transition settles, a matching phase task clears the retained image, resets state, and sets `phase` to `.hidden`.

### Drag return and dismissal

The canvas records drag values directly in presentation state.

When the predicted translation is below the threshold, it animates the direct interaction fields back to their presented values.

When it is above the threshold:

- Use `.matched` when an eligible source is available.
- Otherwise construct `DismissToss`, store `.toss`, and animate to its end offset.
- Set `phase` to `.dismissing` before clearing the external binding so the following `nil` request is idempotent.
- Change `phaseID` to start the cleanup task.
- Invoke the supplied dismiss action.

There is no separate general-purpose `beginDismissal` method. The entire drag decision is visible in the canvas function that ends the drag.

## Accepted internal simplifications

The implementation does not need to preserve distinctions that have no visible result:

- Resuming the same image during dismissal and replacing it during dismissal can share one cancellation path.
- A single phase identity can replace separate session and dismissal identities.
- Opening and dismissal can share one transition type and one phase-completion task.
- Replacements do not need a result enum solely so the host can decide which follow-up callbacks to invoke.
- Interaction and appearance values may temporarily be valid outside their usual phase as long as rendering remains correct and cleanup resets them.
- Source and Reduce Motion changes need only be latched when a transition begins; the state does not need to model every intermediate capability change as a lifecycle event.

The following protections remain required because they affect visible correctness:

- An obsolete task must not clear a newer image.
- A running matched transition must retain the geometry it started with.
- A replacement must not inherit zoom, drag, or hidden-overlay state.
- A first matched presentation must participate in the transaction that removed its source stand-in.
- A matched dismissal must remove the fullscreen image in the transaction that restores its source.

## File organization

Keep the existing main files:

```text
ZoomImageViewerHost.swift
ZoomImagePresentationState.swift
ZoomImageCanvas.swift
ZoomImageViewerScreen.swift
```

Add `ZoomImagePresentationTransition.swift` if the unified transition enum and its operations are substantial enough to stand alone. Otherwise it may live beside presentation state.

Methods should be grouped with the small type whose knowledge they use. Separate files for broad host extensions are explicitly discouraged. A short private extension in the same file is acceptable only when it improves navigation and does not create a second conceptual owner.

## Testing and verification

Because this refactor intentionally weakens type-level lifecycle enforcement, tests should concentrate on observable sequences rather than every internal combination.

Add or update Swift Testing coverage for:

- Transition helper properties for fade, matched, and toss.
- First presentation and phase completion.
- Immediate image replacement and interaction reset.
- Replacement while dismissal cleanup is pending.
- Programmatic fade and matched dismissal.
- Drag return, matched drag dismissal, and toss dismissal.
- An obsolete phase completion after a newer presentation.
- Reduce Motion or source availability changing before versus after a transition starts.

Retain the existing geometry, toss, rotation, zoom, and accessibility helper tests.

Builds and tests are not sufficient to establish animation quality. Before implementation is considered complete, visually verify:

- Fade presentation and dismissal.
- Matched presentation and dismissal.
- Drag return.
- Matched drag landing with slow and fast releases.
- Toss dismissal.
- Immediate replacement, including while dismissal is running.
- A source scrolling on or off screen before dismissal.
- Reduce Motion.
- Wrapper rotation.
- VoiceOver focus, zoom, scroll, escape, and overlay actions.

## Implementation sequence

Each stage should remain reviewable and buildable:

1. Introduce the unified transition type and move transition-derived calculations onto it.
2. Flatten `ZoomImagePresentationState` while temporarily adapting the existing host to it.
3. Replace lifecycle command methods and `PresentationChange` with explicit host assignments.
4. Give `ZoomImageCanvas` direct binding access to presentation state and remove forwarded interaction callbacks and values.
5. Give `ZoomImageViewerScreen` direct presentation-state access and move appearance/accessibility composition into it.
6. Collapse opening and dismissal cleanup into the phase task.
7. Remove obsolete nested types, forwarding properties, callbacks, and comments that describe the old state machine.
8. Run unit, package, example-app, accessibility, and visual verification.

## Acceptance criteria

- `ZoomImagePresentationState` has one shallow `Phase` enum and no stored `Session`, `Dismissal`, `Drag`, or `Appearance` containers.
- `Session.OpeningStyle`, `Dismissal.Style`, and `PresentationChange` are removed.
- Lifecycle changes are readable at their host or canvas call sites without following several semantic state methods.
- Canvas and screen initializers no longer mirror most presentation fields and events.
- Canvas handles image interaction by working with presentation state directly.
- Screen derives its visual and accessibility decisions from presentation state directly.
- General calculations are expressed by the helper types that own the required knowledge.
- The host is primarily external request reconciliation, phase cleanup, and view composition.
- No broad concern-based `ZoomImageViewerHost` extensions are introduced merely to hide long functions.
- Existing public API remains source compatible.
- Normal UI behavior remains visually equivalent, including matched motion, drag continuity, replacement, Reduce Motion, chrome, wrapper rotation, and accessibility.
- Package tests and the example app build successfully, followed by simulator or device interaction verification.

## Implementation notes

The implementation follows this proposal with these differences.

### State

- `ZoomImagePresentationState` is initialized from the image in the binding when the host is created. A non-`nil` image starts in `.appearing` with its opening transition, so a viewer inserted with an image already set still grows or fades in.
- Rendering facts that depend on the latest request take it as a parameter rather than being stored properties: `matchedGeometry(for:)`, `dismissalMatchedGeometry(for:)`, `presentedImage(for:)`, `isShowingImage(for:)` and `presentationOffset(for:)`. A first matched presentation renders from the request in the transaction that removes its source, before `apply` has recorded the image, so these cannot read retained state alone.
- `isShowingSystemOverlay` lives on `ZoomImageViewerScreen`, its only reader, rather than on the state.
- `resetInteraction()` and `resetAppearance()` are the state's only mutating helpers. Animating the viewer in is `showPresentation(usesMatchedGeometry:fadeDuration:)` on `Binding<ZoomImagePresentationState>` rather than on the state, so each opacity change is written inside its own animation. A mutating method would write the whole state back once, outside every animation.

### Transition

`ZoomImagePresentationTransition` lives in its own file and provides `opening(matchedGeometry:reduceMotion:)`, `matchedGeometry`, `keepsImageDuringDismissal`, `settlingDuration(fadeDuration:)` and `imageTransition(undoing:moving:velocity:)`.

### Host

- The host's lifecycle functions are `apply(_:)` and `completePhase(id:)`. There is no separate host `dismiss()`: the close button, escape gesture and overlay call the `ZoomImageDismissAction`, which clears the binding, and the resulting `nil` request reaches `apply(_:)`.
- `onChange(of: request)` is attached inside the `GeometryReader`, and the screen is built only while `presentedImage(for:)` returns an image.
- The fade duration is owned by the host and passed to the canvas and screen.

### Canvas and screen

- The canvas also receives the current request, the image to render, the dismiss action and the fade duration, as well as the viewer size and content rotation.
- The screen reads whether it uses matched geometry from `canvas.request` rather than from the retained transition. A first matched presentation inserts the screen before the host records its opening transition, when the retained transition is still the idle fade.
- The screen animates the viewer in with `showPresentation` when it appears and resets appearance when it disappears. The host calls `showPresentation` itself only when a new request interrupts a dismissal, as the screen is already on screen.

### Lifecycle

- Replacing the image while presented goes straight to `.presented`, as there is no opening transition to settle. Replacing it, or presenting the same image again, during a dismissal goes to `.appearing` and replays the appearance.
- A drag over an image that is already dismissing is ignored. It cannot move the image, put it back, or start a second dismissal.
