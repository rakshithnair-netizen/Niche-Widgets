import SwiftUI

enum GalleryWidgets {
    static let presets = WidgetSizePreset.allCases
    static let customSize = CGSize(width: 260, height: 200)
    static let gradients: [[String]] = [
        ["#2B3040", "#7A86A6"], ["#1F3A33", "#6FBF9A"], ["#3A2033", "#C27A9A"],
        ["#3A2F1F", "#C9A06B"], ["#22204A", "#7D74D6"], ["#0F2C30", "#4FA3A8"]
    ]

    static let matrix: [WidgetModel] = WidgetShape.allCases.enumerated().flatMap { shapeIndex, shape in
        presets.map { preset in
            var model = WidgetModel()
            model.name = "\(shape.title) \(preset.title)"
            model.shape = shape
            model.size = WidgetSize(preset: preset, width: customSize.width, height: customSize.height)
            model.background = WidgetBackground(kind: .linearGradient, color: gradients[shapeIndex][0], gradient: WidgetGradient(colors: gradients[shapeIndex], angle: 135))
            model.textLayers = [
                WidgetTextLayer(content: shortTitle(preset), fontName: "System Rounded", size: 44, weight: .semibold, alignment: .center, x: 0.5, y: 0.5, opacity: 0.9)
            ]
            return model
        }
    }

    static func model(_ shape: WidgetShape, _ preset: WidgetSizePreset) -> WidgetModel? {
        matrix.first { $0.shape == shape && $0.size.preset == preset }
    }

    static let clampBase: WidgetModel = {
        var model = WidgetModel()
        model.name = "Resize Demo"
        model.background = WidgetBackground(kind: .linearGradient, color: "#2B3040", gradient: WidgetGradient(colors: ["#3A4152", "#9AA6C4"], angle: 135))
        model.glass.rimHighlightOpacity = 0.5
        return model
    }()

    private static func shortTitle(_ preset: WidgetSizePreset) -> String {
        switch preset {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        case .extraLarge: "XL"
        case .custom: "C"
        }
    }
}

struct WidgetShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                GalleryCaption("Every shape in every size, drawn by the shared layer renderer")
                WidgetShapeMatrix()
            }
            GlassDivider()
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                GalleryCaption("Resize clamping. Drag the handle; the dashed frame is the request")
                ResizeClampDemo()
            }
            GlassDivider()
            WidgetStressDemo()
        }
    }
}

private struct GalleryCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.textTertiary)
    }
}

private struct WidgetShapeMatrix: View {
    private let scale = DS.Size.galleryWidgetScale

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DS.Spacing.lg, verticalSpacing: DS.Spacing.lg) {
            GridRow {
                GalleryCaption("")
                ForEach(GalleryWidgets.presets) { preset in
                    GalleryCaption(preset.title)
                }
            }
            ForEach(WidgetShape.allCases) { shape in
                GridRow(alignment: .center) {
                    GalleryCaption(shape.title)
                        .frame(width: DS.Size.galleryColumn, alignment: .leading)
                    ForEach(GalleryWidgets.presets) { preset in
                        if let model = GalleryWidgets.model(shape, preset) {
                            let size = model.resolvedSize
                            WidgetTile(model: model)
                                .frame(width: size.width * scale, height: size.height * scale)
                        }
                    }
                }
            }
        }
    }
}

private struct ResizeClampDemo: View {
    @State private var shape = WidgetShape.widePill
    @State private var requested = CGSize(width: 320, height: 240)
    private let scale = DS.Size.galleryClampScale
    private let space = "clampCanvas"

    private var model: WidgetModel {
        var model = GalleryWidgets.clampBase
        model.shape = shape
        model.size = WidgetSize(preset: .custom, width: requested.width, height: requested.height)
        return model
    }

    private var rule: String {
        switch shape {
        case .circle, .square: "Locked to 1:1"
        case .widePill: "Width at least 2× height"
        case .tallCard: "Height at least 1.5× width"
        case .roundedRect, .squircle: "Free aspect"
        }
    }

    var body: some View {
        let clamped = model.resolvedSize
        let canvas = WidgetSizing.maxSide * scale
        let canvasShape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            GlassSegmentedControl(WidgetShape.allCases, selection: $shape) { $0.title }
            HStack(alignment: .top, spacing: DS.Spacing.xl) {
                ZStack(alignment: .topLeading) {
                    canvasShape.fill(DS.Palette.fillSubtle)
                    Rectangle()
                        .strokeBorder(DS.Palette.hairline, style: StrokeStyle(lineWidth: DS.Stroke.hairline, dash: DS.Size.dash))
                        .frame(width: WidgetSizing.minSide * scale, height: WidgetSizing.minSide * scale)
                    WidgetTile(model: model)
                        .frame(width: clamped.width * scale, height: clamped.height * scale)
                    Rectangle()
                        .strokeBorder(DS.Palette.accent, style: StrokeStyle(lineWidth: DS.Stroke.focus, dash: DS.Size.dash))
                        .frame(width: max(requested.width * scale, 1), height: max(requested.height * scale, 1))
                        .allowsHitTesting(false)
                    Circle()
                        .fill(DS.Palette.knob)
                        .glassEffect(.regular.tint(DS.Glass.knob), in: Circle())
                        .glassRim(Circle())
                        .frame(width: DS.Size.resizeHandle, height: DS.Size.resizeHandle)
                        .position(x: requested.width * scale, y: requested.height * scale)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                                .onChanged { value in
                                    requested = CGSize(
                                        width: min(max(value.location.x, 0), canvas) / scale,
                                        height: min(max(value.location.y, 0), canvas) / scale
                                    )
                                }
                        )
                }
                .frame(width: canvas, height: canvas)
                .clipShape(canvasShape)
                .glassRim(canvasShape)
                .coordinateSpace(name: space)
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    readout("Requested", requested)
                    readout("Clamped", clamped)
                    readout("Rule", text: rule)
                    readout("Limits", text: "\(Int(WidgetSizing.minSide)) to \(Int(WidgetSizing.maxSide)) pt per side")
                }
                .frame(width: DS.Size.galleryReadoutWidth, alignment: .leading)
            }
        }
    }

    private func readout(_ title: String, _ size: CGSize) -> some View {
        readout(title, text: "\(Int(size.width.rounded())) × \(Int(size.height.rounded()))")
    }

    private func readout(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            SectionLabel(title)
            Text(text)
                .font(DS.Typography.bodyEmphasis)
                .foregroundStyle(DS.Palette.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

private struct WidgetStressDemo: View {
    static let count = 100
    static let columns = 10

    @State private var isOn = false
    @Environment(WidgetLibrary.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let widgets = library.widgets
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            GlassToggle("Render 100 widgets", subtitle: "Every tile is its own layer tree from the shared renderer", isOn: $isOn)
            if isOn && !widgets.isEmpty {
                Grid(horizontalSpacing: DS.Spacing.sm, verticalSpacing: DS.Spacing.sm) {
                    ForEach(0..<(Self.count / Self.columns), id: \.self) { row in
                        GridRow {
                            ForEach(0..<Self.columns, id: \.self) { column in
                                WidgetTile(model: widgets[(row * Self.columns + column) % widgets.count])
                                    .frame(width: DS.Size.stressTile, height: DS.Size.stressTile)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: DS.Interaction.appearScale)))
            }
        }
        .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: isOn)
    }
}
