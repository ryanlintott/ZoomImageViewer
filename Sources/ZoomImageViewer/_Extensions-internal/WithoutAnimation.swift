//
//  WithoutAnimation.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2026-09-17.
//

import SwiftUI

/// Returns the result of recomputing the view's body with animations disabled, even inside a caller's `withAnimation`.
///
/// The counterpart to `withAnimation(_:_:)`, for state changes that must apply at once.
func withoutAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    return try withTransaction(transaction, body)
}
