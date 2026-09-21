//
//  PresentationRequestTests.swift
//  ZoomImageViewerTests
//
//  Created by Ryan Lintott on 2026-09-18.
//

import SwiftUI
import Testing
@testable import ZoomImageViewer

@MainActor
@Suite("Presentation request")
struct PresentationRequestTests {
    @Test("A newly resolved source triggers reconciliation for the same image")
    func sourceChangeTriggersReconciliation() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        let matchedGeometry = ZoomImageMatchedGeometry(
            id: ZoomImageSourceID(itemType: Int.self, itemID: 1),
            namespace: Namespace().wrappedValue
        )
        let before = ZoomImagePresentationRequest(image: image, matchedGeometry: nil, reduceMotion: false)
        let after = ZoomImagePresentationRequest(image: image, matchedGeometry: matchedGeometry, reduceMotion: false)

        #expect(before != after)
    }

    @Test("A request compares images by identity")
    func imagesCompareByIdentity() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let firstImage = renderer.image { _ in }
        let secondImage = renderer.image { _ in }

        #expect(
            ZoomImagePresentationRequest(image: firstImage, matchedGeometry: nil, reduceMotion: false)
                != ZoomImagePresentationRequest(image: secondImage, matchedGeometry: nil, reduceMotion: false)
        )
    }
}
