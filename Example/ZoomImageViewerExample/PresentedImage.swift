//
//  PresentedImage.swift
//  ZoomImageViewerExample
//
//  Created by Ryan Lintott on 2026-09-21.
//

import UIKit

/// Every kind of item the example's single zoom image viewer can present.
enum PresentedImage: Identifiable, Equatable {
    /// A photo whose thumbnail is its source view.
    case sourcedPhoto(ThumbnailPhoto)
    /// A photo with no source view, so it fades in and out.
    case sourceLessPhoto(ThumbnailPhoto)
    /// A generated image used to exercise viewer sizing and controls.
    case testImage(TestImage, UIImage)

    enum ID: Hashable {
        case sourcedPhoto(ThumbnailPhoto.ID)
        case sourceLessPhoto(ThumbnailPhoto.ID)
        case testImage(TestImage.ID)
    }

    var id: ID {
        switch self {
        case .sourcedPhoto(let photo):
            .sourcedPhoto(photo.id)
        case .sourceLessPhoto(let photo):
            .sourceLessPhoto(photo.id)
        case .testImage(let testImage, _):
            .testImage(testImage.id)
        }
    }

    /// The same stored image instance each time it is read.
    var image: UIImage {
        switch self {
        case .sourcedPhoto(let photo), .sourceLessPhoto(let photo):
            photo.image
        case .testImage(_, let image):
            image
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.sourcedPhoto(let lhs), .sourcedPhoto(let rhs)):
            lhs == rhs
        case (.sourceLessPhoto(let lhs), .sourceLessPhoto(let rhs)):
            lhs == rhs
        case (.testImage(let lhsTestImage, let lhsImage), .testImage(let rhsTestImage, let rhsImage)):
            lhsTestImage == rhsTestImage && lhsImage === rhsImage
        default:
            false
        }
    }
}
