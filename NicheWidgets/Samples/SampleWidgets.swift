import Foundation

enum SampleWidgets {
    static func make(now: Date = Date()) -> [WidgetModel] {
        let models = [
            fogClock, sageWeather, batteryOrb, morningPages, focus,
            ambient, strataCalendar, tideMoon, nightSteps, violetNotes
        ]
        return models.enumerated().map { index, model in
            var stamped = model
            stamped.createdAt = now.addingTimeInterval(Double(index))
            stamped.modifiedAt = stamped.createdAt
            return stamped
        }
    }

    private static func text(
        _ content: String,
        size: Double,
        weight: WidgetFontWeight = .regular,
        font: String = "System",
        x: Double,
        y: Double,
        alignment: WidgetTextAlignment = .leading,
        color: String = "#FFFFFF",
        opacity: Double = 1
    ) -> WidgetTextLayer {
        WidgetTextLayer(content: content, fontName: font, size: size, weight: weight, color: color, alignment: alignment, x: x, y: y, opacity: opacity)
    }

    private static func gradient(_ colors: [String], angle: Double) -> WidgetBackground {
        WidgetBackground(kind: .linearGradient, color: colors.first ?? "#1C1C22", gradient: WidgetGradient(colors: colors, angle: angle))
    }

    private static func imageBackground(_ fallback: String) -> WidgetBackground {
        WidgetBackground(kind: .image, color: fallback, gradient: WidgetGradient())
    }

    private static var fogClock: WidgetModel {
        var model = WidgetModel()
        model.name = "Fog Clock"
        model.shape = .widePill
        model.size = WidgetSize(preset: .medium)
        model.background = gradient(["#3A4152", "#8A93A6"], angle: 120)
        model.glass.rimHighlightOpacity = 0.45
        model.textLayers = [
            text("09:41", size: 48, weight: .semibold, font: "System Rounded", x: 0.1, y: 0.42),
            text("Monday, October 27", size: 14, weight: .medium, x: 0.1, y: 0.74, opacity: 0.75)
        ]
        return model
    }

    private static var sageWeather: WidgetModel {
        var model = WidgetModel()
        model.name = "Sage Weather"
        model.shape = .square
        model.size = WidgetSize(preset: .small)
        model.background = imageBackground("#141B33")
        model.image = WidgetImage(reference: ProceduralArtwork.aurora.reference)
        model.overlay = WidgetOverlay(direction: .bottom, opacity: 0.6, color: "#000000", extent: 0.7)
        model.textLayers = [
            text("14°", size: 40, weight: .bold, x: 0.11, y: 0.62),
            text("Fog, light wind", size: 12, weight: .medium, x: 0.11, y: 0.84, opacity: 0.8)
        ]
        return model
    }

    private static var batteryOrb: WidgetModel {
        var model = WidgetModel()
        model.name = "Battery Orb"
        model.shape = .circle
        model.size = WidgetSize(preset: .small)
        model.background = gradient(["#1E3B34", "#6FBF9A"], angle: 160)
        model.glass.rimHighlightOpacity = 0.5
        model.textLayers = [
            text("68%", size: 34, weight: .semibold, font: "System Rounded", x: 0.5, y: 0.46, alignment: .center),
            text("Battery", size: 11, weight: .medium, x: 0.5, y: 0.68, alignment: .center, opacity: 0.7)
        ]
        return model
    }

    private static var morningPages: WidgetModel {
        var model = WidgetModel()
        model.name = "Morning Pages"
        model.shape = .tallCard
        model.size = WidgetSize(preset: .large)
        model.cornerRadius = 28
        model.background = imageBackground("#331C29")
        model.image = WidgetImage(reference: ProceduralArtwork.dunes.reference)
        model.overlay = WidgetOverlay(direction: .bottom, opacity: 0.65, color: "#1A0C14", extent: 0.55)
        model.textLayers = [
            text("Pages", size: 30, weight: .bold, font: "System Serif", x: 0.09, y: 0.76),
            text("3 of 5 done", size: 13, weight: .medium, x: 0.09, y: 0.86, opacity: 0.8)
        ]
        return model
    }

    private static var focus: WidgetModel {
        var model = WidgetModel()
        model.name = "Focus"
        model.shape = .roundedRect
        model.size = WidgetSize(preset: .medium)
        model.background = WidgetBackground(kind: .solid, color: "#1A1C24", gradient: WidgetGradient())
        model.glass.tintColor = "#7DA2FF"
        model.glass.tintOpacity = 0.16
        model.borderOpacity = 0.2
        model.textLayers = [
            text("25:00", size: 44, weight: .medium, font: "System Mono", x: 0.08, y: 0.44),
            text("Focus session", size: 13, weight: .medium, x: 0.08, y: 0.74, opacity: 0.7)
        ]
        return model
    }

    private static var ambient: WidgetModel {
        var model = WidgetModel()
        model.name = "Ambient"
        model.shape = .squircle
        model.size = WidgetSize(preset: .large)
        model.background = imageBackground("#0B0F1A")
        model.image = WidgetImage(reference: ProceduralArtwork.orbs.reference, zoom: 1.2)
        model.glass.tintColor = "#000000"
        model.glass.tintOpacity = 0.1
        model.glass.rimHighlightOpacity = 0.5
        return model
    }

    private static var strataCalendar: WidgetModel {
        var model = WidgetModel()
        model.name = "Strata Calendar"
        model.shape = .roundedRect
        model.size = WidgetSize(preset: .extraLarge)
        model.cornerRadius = 30
        model.background = imageBackground("#2E2A27")
        model.image = WidgetImage(reference: ProceduralArtwork.strata.reference)
        model.overlay = WidgetOverlay(direction: .leading, opacity: 0.7, color: "#000000", extent: 0.75)
        model.textLayers = [
            text("October", size: 40, weight: .bold, x: 0.05, y: 0.36),
            text("27  Monday", size: 18, weight: .medium, x: 0.05, y: 0.56),
            text("No events today", size: 13, weight: .regular, x: 0.05, y: 0.72, opacity: 0.7)
        ]
        return model
    }

    private static var tideMoon: WidgetModel {
        var model = WidgetModel()
        model.name = "Tide Moon"
        model.shape = .circle
        model.size = WidgetSize(preset: .custom, width: 220, height: 220)
        model.background = imageBackground("#3D2B56")
        model.image = WidgetImage(reference: ProceduralArtwork.grain.reference, rotation: 18)
        model.glass.blurRadius = 2
        model.textLayers = [
            text("Waxing", size: 20, weight: .semibold, font: "System Serif", x: 0.5, y: 0.5, alignment: .center)
        ]
        return model
    }

    private static var nightSteps: WidgetModel {
        var model = WidgetModel()
        model.name = "Night Steps"
        model.shape = .widePill
        model.size = WidgetSize(preset: .custom, width: 420, height: 150)
        model.background = gradient(["#141A33", "#3C2F6B", "#7A4E9C"], angle: 90)
        model.textLayers = [
            text("8,204", size: 40, weight: .semibold, font: "System Rounded", x: 0.09, y: 0.44),
            text("steps today", size: 13, weight: .medium, x: 0.09, y: 0.72, opacity: 0.75),
            text("82%", size: 22, weight: .semibold, x: 0.9, y: 0.5, alignment: .trailing, opacity: 0.9)
        ]
        return model
    }

    private static var violetNotes: WidgetModel {
        var model = WidgetModel()
        model.name = "Violet Notes"
        model.shape = .squircle
        model.size = WidgetSize(preset: .small)
        model.background = gradient(["#2A1F3D", "#8C6BC8"], angle: 150)
        model.textLayers = [
            text("Notes", size: 22, weight: .semibold, x: 0.5, y: 0.45, alignment: .center),
            text("3 pinned", size: 11, weight: .medium, x: 0.5, y: 0.64, alignment: .center, opacity: 0.7)
        ]
        return model
    }
}

enum SampleLibrary {
    static func seedIfNeeded(store: WidgetStore, disk: ImageDiskCache) async throws {
        try await ProceduralArtwork.generateMissing(in: disk)
        guard !FileManager.default.fileExists(atPath: AppDirectories.samplesMarker.path) else { return }
        for model in SampleWidgets.make() {
            try await store.create(model)
        }
        try Data().write(to: AppDirectories.samplesMarker, options: .atomic)
    }
}
