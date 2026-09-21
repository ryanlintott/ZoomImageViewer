//
//  SourceIDTests.swift
//  ZoomImageViewerTests
//
//  Created by Ryan Lintott on 2026-09-21.
//

import Testing
@testable import ZoomImageViewer

@Suite("Source identifier")
struct SourceIDTests {
    @Test("Equal identifiers from the same item type match")
    func sameItemTypeMatches() {
        #expect(ZoomImageSourceID(FirstItem(id: 1)) == ZoomImageSourceID(FirstItem(id: 1)))
    }

    @Test("Equal raw identifiers from different item types do not match")
    func differentItemTypesDoNotMatch() {
        #expect(ZoomImageSourceID(FirstItem(id: 1)) != ZoomImageSourceID(SecondItem(id: 1)))
    }
}

private struct FirstItem: Identifiable {
    let id: Int
}

private struct SecondItem: Identifiable {
    let id: Int
}
