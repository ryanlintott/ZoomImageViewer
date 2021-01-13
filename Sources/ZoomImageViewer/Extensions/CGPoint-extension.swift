//
//  CGPoint-extension.swift
//  FullscreenZoom
//
//  Created by Ryan Lintott on 2020-09-22.
//

import SwiftUI

extension CGPoint {
    // Vector negation
    static prefix func - (cgPoint: CGPoint) -> CGPoint {
        return CGPoint(x: -cgPoint.x, y: -cgPoint.y)
    }
    
    // Vector addition
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    // Vector subtraction
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return lhs + -rhs
    }
    
    // Vector addition assignment
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    // Vector subtraction assignment
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
}

extension CGPoint {
    // Scalar-vector multiplication
    static func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs * rhs.x, y: lhs * rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return rhs * lhs
    }
    
    // Vector-scalar division
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        guard rhs != 0 else { fatalError("Division by zero") }
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    // Vector-scalar division assignment
    static func /= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs / rhs
    }
    
    // Scalar-vector multiplication assignment
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
    }
}

extension CGPoint: Comparable {
    // Vector magnitude (length)
    var magnitude: CGFloat {
        return sqrt(x * x + y * y)
    }
    
    // Vector normalization
    var normalized: CGPoint {
        return CGPoint(x: x / magnitude, y: y / magnitude)
    }
    
    public static func < (lhs: CGPoint, rhs: CGPoint) -> Bool {
        lhs.magnitude < rhs.magnitude
    }
}

extension CGPoint {
    var aspectRatio: CGFloat {
        x / y
    }
    
    init(cgSize: CGSize) {
        self = CGPoint(x: cgSize.width, y: cgSize.height)
    }
}
