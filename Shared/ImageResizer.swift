import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageResizer {
    /// Longest edge, in pixels, of every image that goes to Firestore or the App Group.
    static let maxPixelSize = 600
    /// Must stay in sync with the imageData size limit in firestore.rules.
    static let maxUploadBytes = 200 * 1024

    /// Downsamples without decoding the full-size image into memory (safe inside the widget).
    static func downsampledJPEG(from data: Data,
                                maxPixelSize: Int = maxPixelSize,
                                quality: Double = 0.8) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let destinationOptions = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, destinationOptions)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Downsamples and lowers JPEG quality until the result fits `maxUploadBytes`.
    static func jpegForUpload(from data: Data) -> Data? {
        for quality in [0.8, 0.65, 0.5, 0.35] {
            guard let jpeg = downsampledJPEG(from: data, quality: quality) else { return nil }
            if jpeg.count <= maxUploadBytes { return jpeg }
        }
        return nil
    }
}
