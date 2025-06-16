//
//  CGSize-extension.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI

internal extension CGSize {
    // Vector negation
    static prefix func - (cgSize: CGSize) -> CGSize {
        return CGSize(width: -cgSize.width, height: -cgSize.height)
    }
    
    // Vector addition
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    // Vector subtraction
    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        return lhs + -rhs
    }
    
    // Vector addition assignment
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
    
    // Vector subtraction assignment
    static func -= (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs - rhs
    }
    
    // Scalar-vector multiplication
    static func * (lhs: CGFloat, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs * rhs.width, height: lhs * rhs.height)
    }
    
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return rhs * lhs
    }
    
    // Vector-scalar division
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        guard rhs != 0 else { fatalError("Division by zero") }
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    // Vector-scalar division assignment
    static func /= (lhs: inout CGSize, rhs: CGFloat) {
        lhs = lhs / rhs
    }
    
    // Scalar-vector multiplication assignment
    static func *= (lhs: inout CGSize, rhs: CGFloat) {
        lhs = lhs * rhs
    }
    
    // Vector magnitude (length)
    var magnitude: CGFloat {
        return sqrt(width * width + height * height)
    }
    
    // Vector normalization
    var normalized: CGSize {
        return CGSize(width: width / magnitude, height: height / magnitude)
    }
    
    static func max(_ x: CGSize, _ y: CGSize) -> CGSize {
        x.magnitude > y.magnitude ? x : y
    }
    
    var aspectRatio: CGFloat {
        width / height
    }
}


