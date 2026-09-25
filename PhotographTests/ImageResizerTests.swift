import UIKit
import XCTest
@testable import photograph

final class ImageResizerTests: XCTestCase {
    func testDownsamplesLongEdgeTo600px() throws {
        let original = try XCTUnwrap(Self.makeJPEG(width: 4000, height: 3000))
        let resized = try XCTUnwrap(ImageResizer.downsampledJPEG(from: original))
        let image = try XCTUnwrap(UIImage(data: resized))
        XCTAssertEqual(max(image.size.width, image.size.height) * image.scale, 600, accuracy: 1)
        XCTAssertEqual(image.size.width / image.size.height, 4.0 / 3.0, accuracy: 0.01)
    }

    func testDoesNotUpscaleSmallImages() throws {
        let original = try XCTUnwrap(Self.makeJPEG(width: 300, height: 200))
        let resized = try XCTUnwrap(ImageResizer.downsampledJPEG(from: original))
        let image = try XCTUnwrap(UIImage(data: resized))
        XCTAssertEqual(image.size.width * image.scale, 300, accuracy: 1)
    }

    func testUploadFitsFirestoreRuleLimit() throws {
        let original = try XCTUnwrap(Self.makeJPEG(width: 4000, height: 3000, noisy: true))
        let upload = try XCTUnwrap(ImageResizer.jpegForUpload(from: original))
        XCTAssertLessThanOrEqual(upload.count, ImageResizer.maxUploadBytes)
    }

    func testRejectsNonImageData() {
        XCTAssertNil(ImageResizer.downsampledJPEG(from: Data("not an image".utf8)))
    }

    /// Noisy images compress badly, which is the worst case for the upload size limit.
    private static func makeJPEG(width: Int, height: Int, noisy: Bool = false) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            guard noisy else { return }
            var generator = SystemRandomNumberGenerator()
            for _ in 0..<20_000 {
                let hue = CGFloat.random(in: 0...1, using: &generator)
                UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1).setFill()
                let x = Double.random(in: 0..<Double(width), using: &generator)
                let y = Double.random(in: 0..<Double(height), using: &generator)
                context.fill(CGRect(x: x, y: y, width: 12.0, height: 12.0))
            }
        }
        return image.jpegData(compressionQuality: 1)
    }
}
