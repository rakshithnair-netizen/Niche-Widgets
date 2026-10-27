import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Niche_Widgets

struct PaletteExtractorTests {
    private static let stripes: [(Double, Double, Double)] = [
        (0.85, 0.1, 0.15), (0.1, 0.6, 0.2), (0.15, 0.25, 0.85), (0.95, 0.85, 0.2), (0.1, 0.1, 0.1)
    ]

    private func stripedImage(width: Int = 500, height: Int = 300) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let stripe = CGFloat(width) / CGFloat(Self.stripes.count)
        for (index, color) in Self.stripes.enumerated() {
            context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
            context.fill(CGRect(x: CGFloat(index) * stripe, y: 0, width: stripe, height: CGFloat(height)))
        }
        return context.makeImage()
    }

    private func isHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-F]{6}$", options: .regularExpression) != nil
    }

    @Test func extractsFiveValidHexColors() throws {
        let image = try #require(stripedImage())
        let palette = PaletteExtractor.palette(from: image)
        #expect(palette.count == 5)
        #expect(palette.allSatisfy(isHex))
        #expect(Set(palette).count == 5)
        for expected in Self.stripes {
            let match = palette.compactMap(HexColor.parse).contains { rgba in
                abs(rgba.red - expected.0) < 0.08 && abs(rgba.green - expected.1) < 0.08 && abs(rgba.blue - expected.2) < 0.08
            }
            #expect(match)
        }
    }

    @Test func solidImageStillYieldsFiveColors() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.6, green: 0.3, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let image = try #require(context.makeImage())
        let palette = PaletteExtractor.palette(from: image)
        #expect(palette.count == 5)
        #expect(palette.allSatisfy(isHex))
        #expect(palette.first == "#994D80")
    }

    @Test func attachmentLoaderDownsamplesAndExtracts() async throws {
        let image = try #require(stripedImage(width: 2400, height: 1600))
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        let attachment = try await ImageAttachmentLoader.load(data: data as Data, name: "stripes.png")
        #expect(max(attachment.thumbnail.width, attachment.thumbnail.height) <= ImageAttachmentLoader.thumbnailPixelSize)
        #expect(attachment.palette.count == 5)
        #expect(attachment.palette.allSatisfy(isHex))
    }

    @Test func combinedPaletteInterleavesAttachments() throws {
        let image = try #require(stripedImage())
        let a = ImageAttachment(name: "a", thumbnail: image, palette: ["#000001", "#000002", "#000003"])
        let b = ImageAttachment(name: "b", thumbnail: image, palette: ["#100000", "#000002", "#300000"])
        #expect(ImageAttachmentLoader.combinedPalette([a, b]) == ["#000001", "#100000", "#000002", "#000003", "#300000"])
    }
}
