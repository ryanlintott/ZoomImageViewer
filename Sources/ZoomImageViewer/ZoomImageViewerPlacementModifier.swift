//
//  ZoomImageViewerPlacementModifier.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI

/// The item type and presented item of a viewer that grows its images from source views.
struct ZoomImageViewerSources {
    let itemType: ObjectIdentifier
    /// Kept as its original type because SwiftUI does not match a type-erased `AnyHashable` to the underlying identifier.
    let presentedID: (any Hashable)?
}

/// Places a viewer over the modified view and connects it to source views inside that view.
struct ZoomImageViewerModifier<Overlay: View>: ViewModifier {
    @Environment(\.zoomImageSourceViewers) private var viewers
    @Environment(\.zoomImageViewerWrapper) private var wrapper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    @Binding var uiImage: UIImage?
    let closeAction: ZoomImageCloseAction
    let overlay: Overlay
    /// Either always present or always absent for the life of this modifier, according to the public overload used.
    let sources: ZoomImageViewerSources?

    func body(content: Content) -> some View {
        if let sources {
            content
                .environment(\.zoomImageSourceViewers, viewers.merging([sources.itemType: sourceViewer(for: sources)]) { $1 })
                .overlayPreferenceValue(ZoomImageSourceIDs.self) { sourceIDs in
                    wrapped(
                        ZoomImageViewerHost(
                            uiImage: $uiImage,
                            closeAction: closeAction,
                            overlay: overlay,
                            matchedGeometry: matchedGeometry(
                                for: sources,
                                onScreen: sourceIDs[sources.itemType] ?? []
                            ),
                            reduceMotionAtInsertion: reduceMotion
                        )
                        .animation(ZoomImageMatchedGeometry.landingAnimation(), value: uiImage != nil)
                    )
                }
                /// Sources inside belong to this viewer, not another viewer of the same item type further out.
                .transformPreference(ZoomImageSourceIDs.self) { sourceIDs in
                    sourceIDs[sources.itemType] = nil
                }
        } else {
            content.overlay {
                wrapped(
                    ZoomImageViewerHost(
                        uiImage: $uiImage,
                        closeAction: closeAction,
                        overlay: overlay,
                        matchedGeometry: nil,
                        reduceMotionAtInsertion: reduceMotion
                    )
                )
            }
        }
    }

    func sourceViewer(for sources: ZoomImageViewerSources) -> ZoomImageSourceViewer {
        ZoomImageSourceViewer(
            namespace: namespace,
            presentedID: sources.presentedID.map { AnyHashable($0) }
        )
    }

    func matchedGeometry(
        for sources: ZoomImageViewerSources,
        onScreen: Set<AnyHashable>
    ) -> ZoomImageMatchedGeometry? {
        guard let id = sources.presentedID, onScreen.contains(AnyHashable(id)) else { return nil }
        return ZoomImageMatchedGeometry(id: id, namespace: namespace)
    }

    /// The only point where the public wrapper's required type erasure enters normal viewer placement.
    @ViewBuilder
    func wrapped(_ viewer: some View) -> some View {
        if let wrapper {
            wrapper.wrap(ZoomImageViewerContent(viewer))
        } else {
            viewer
        }
    }
}
