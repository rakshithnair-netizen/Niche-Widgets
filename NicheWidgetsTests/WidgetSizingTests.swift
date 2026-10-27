import CoreGraphics
import Testing
@testable import Niche_Widgets

struct WidgetSizingTests {
    static let probes: [CGSize] = {
        let sides: [CGFloat] = [-50, 0, 40, 99, 100, 101, 158, 220, 338, 449, 450, 451, 600, 698, 899, 900, 1200, .infinity, .nan]
        return sides.flatMap { width in sides.map { CGSize(width: width, height: $0) } }
    }()

    private func assertInvariants(_ size: CGSize, shape: WidgetShape) {
        #expect(size.width >= WidgetSizing.minSide && size.width <= WidgetSizing.maxSide)
        #expect(size.height >= WidgetSizing.minSide && size.height <= WidgetSizing.maxSide)
        switch shape {
        case .circle, .square:
            #expect(size.width == size.height)
        case .widePill:
            #expect(size.width >= size.height * WidgetSizing.pillRatio)
        case .tallCard:
            #expect(size.height >= size.width * WidgetSizing.tallRatio)
        case .roundedRect, .squircle:
            break
        }
    }

    @Test(arguments: WidgetShape.allCases)
    func everyProbeSatisfiesShapeRules(shape: WidgetShape) {
        for probe in Self.probes {
            assertInvariants(WidgetSizing.clamp(probe, shape: shape), shape: shape)
        }
    }

    @Test(arguments: WidgetShape.allCases)
    func clampingIsIdempotent(shape: WidgetShape) {
        for probe in Self.probes {
            let once = WidgetSizing.clamp(probe, shape: shape)
            #expect(WidgetSizing.clamp(once, shape: shape) == once)
        }
    }

    @Test(arguments: WidgetShape.allCases, WidgetSizePreset.allCases)
    func everyPresetResolvesWithinRules(shape: WidgetShape, preset: WidgetSizePreset) {
        var model = WidgetModel()
        model.shape = shape
        model.size = WidgetSize(preset: preset, width: 333, height: 222)
        assertInvariants(model.resolvedSize, shape: shape)
    }

    @Test func presetDimensions() {
        #expect(WidgetSizePreset.small.dimensions == CGSize(width: 158, height: 158))
        #expect(WidgetSizePreset.medium.dimensions == CGSize(width: 338, height: 158))
        #expect(WidgetSizePreset.large.dimensions == CGSize(width: 338, height: 338))
        #expect(WidgetSizePreset.extraLarge.dimensions == CGSize(width: 698, height: 338))
        #expect(WidgetSizePreset.custom.dimensions == nil)
    }

    @Test func freeShapesOnlyClampRange() {
        #expect(WidgetSizing.clamp(CGSize(width: 50, height: 1000), shape: .roundedRect) == CGSize(width: 100, height: 900))
        #expect(WidgetSizing.clamp(CGSize(width: 420, height: 260), shape: .squircle) == CGSize(width: 420, height: 260))
    }

    @Test func squareAndCircleLockToSmallerSide() {
        #expect(WidgetSizing.clamp(CGSize(width: 338, height: 158), shape: .square) == CGSize(width: 158, height: 158))
        #expect(WidgetSizing.clamp(CGSize(width: 40, height: 500), shape: .circle) == CGSize(width: 100, height: 100))
    }

    @Test func widePillKeepsWidthAtLeastTwiceHeight() {
        #expect(WidgetSizing.clamp(CGSize(width: 338, height: 158), shape: .widePill) == CGSize(width: 338, height: 158))
        #expect(WidgetSizing.clamp(CGSize(width: 300, height: 300), shape: .widePill) == CGSize(width: 300, height: 150))
        #expect(WidgetSizing.clamp(CGSize(width: 158, height: 158), shape: .widePill) == CGSize(width: 200, height: 100))
        #expect(WidgetSizing.clamp(CGSize(width: 900, height: 900), shape: .widePill) == CGSize(width: 900, height: 450))
    }

    @Test func tallCardKeepsHeightAtLeastOneAndAHalfWidth() {
        #expect(WidgetSizing.clamp(CGSize(width: 338, height: 338), shape: .tallCard) == CGSize(width: 225, height: 338))
        #expect(WidgetSizing.clamp(CGSize(width: 200, height: 400), shape: .tallCard) == CGSize(width: 200, height: 400))
        #expect(WidgetSizing.clamp(CGSize(width: 100, height: 100), shape: .tallCard) == CGSize(width: 100, height: 150))
        #expect(WidgetSizing.clamp(CGSize(width: 900, height: 900), shape: .tallCard) == CGSize(width: 600, height: 900))
    }

    @Test func superellipseIsSymmetricAndInsideBounds() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 120)
        let box = WidgetShapePath.superellipse(in: rect).boundingBoxOfPath
        #expect(abs(box.minX - rect.minX) < 0.01)
        #expect(abs(box.maxX - rect.maxX) < 0.01)
        #expect(abs(box.minY - rect.minY) < 0.01)
        #expect(abs(box.maxY - rect.maxY) < 0.01)
    }
}
