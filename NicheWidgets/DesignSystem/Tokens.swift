import SwiftUI

enum DS {
    enum Palette {
        static let textPrimary = Color.white.opacity(0.94)
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary = Color.white.opacity(0.4)
        static let textOnPrimary = Color.white
        static let accent = Color(red: 0.74, green: 0.83, blue: 1.0)
        static let focusGlow = Color(red: 0.66, green: 0.78, blue: 1.0)
        static let success = Color(red: 0.52, green: 0.86, blue: 0.66)
        static let danger = Color(red: 1.0, green: 0.5, blue: 0.5)
        static let hairline = Color.white.opacity(0.08)
        static let fillSubtle = Color.white.opacity(0.035)
        static let fillHover = Color.white.opacity(0.06)
        static let fillSelected = Color.white.opacity(0.11)
        static let skeleton = Color.white.opacity(0.08)
        static let shimmer = Color.white.opacity(0.14)
        static let trackOff = Color.white.opacity(0.1)
        static let trackOn = Color(red: 0.6, green: 0.72, blue: 0.98).opacity(0.6)
        static let knob = Color.white.opacity(0.72)
        static let rimBright = Color.white.opacity(0.42)
        static let rimMid = Color.white.opacity(0.16)
        static let rimDim = Color.white.opacity(0.04)
        static let innerGlow = Color.white.opacity(0.1)
        static let innerShade = Color.black.opacity(0.4)
        static let widgetText = Color.white
        static let widgetTextSecondary = Color.white.opacity(0.72)
        static let artworkHighlight = Color.white.opacity(0.2)
        static let artwork: [[Color]] = [
            [Color(red: 0.14, green: 0.16, blue: 0.22), Color(red: 0.38, green: 0.43, blue: 0.56)],
            [Color(red: 0.13, green: 0.19, blue: 0.16), Color(red: 0.42, green: 0.54, blue: 0.44)],
            [Color(red: 0.22, green: 0.13, blue: 0.18), Color(red: 0.58, green: 0.36, blue: 0.44)],
            [Color(red: 0.2, green: 0.17, blue: 0.12), Color(red: 0.62, green: 0.5, blue: 0.34)],
            [Color(red: 0.13, green: 0.12, blue: 0.24), Color(red: 0.44, green: 0.4, blue: 0.72)],
            [Color(red: 0.1, green: 0.1, blue: 0.11), Color(red: 0.36, green: 0.37, blue: 0.4)],
            [Color(red: 0.08, green: 0.17, blue: 0.19), Color(red: 0.3, green: 0.52, blue: 0.54)]
        ]
    }

    enum Glass {
        static let windowTint = Color.black
        static let windowTintOpacity: Double = 0.85
        static let surface = Color.white.opacity(0.03)
        static let raised = Color.white.opacity(0.07)
        static let primary = Color.white.opacity(0.26)
        static let secondary = Color.white.opacity(0.08)
        static let bubbleUser = Color.white.opacity(0.14)
        static let bubbleAssistant = Color.white.opacity(0.04)
        static let knob = Color.white.opacity(0.5)
    }

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 26
        static let scale: [(name: String, value: CGFloat)] = [("xs", xs), ("sm", sm), ("md", md), ("lg", lg), ("xl", xl)]
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        static let scale: [(name: String, value: CGFloat)] = [("xxs", xxs), ("xs", xs), ("sm", sm), ("md", md), ("lg", lg), ("xl", xl), ("xxl", xxl), ("xxxl", xxxl)]
    }

    enum Typography {
        static let display = Font.system(size: 26, weight: .bold)
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let bodyEmphasis = Font.system(size: 13, weight: .medium)
        static let label = Font.system(size: 12, weight: .semibold)
        static let caption = Font.system(size: 11, weight: .medium)
        static let micro = Font.system(size: 10, weight: .semibold)
        static let icon = Font.system(size: 13, weight: .semibold)
        static let iconLarge = Font.system(size: 24, weight: .medium)
        static let widgetValue = Font.system(size: 22, weight: .semibold)
        static let microTracking: CGFloat = 0.8
        static let scale: [(name: String, font: Font)] = [
            ("Display 26 Bold", display), ("Title 20 Semibold", title), ("Headline 15 Semibold", headline),
            ("Body 13 Regular", body), ("Body 13 Medium", bodyEmphasis), ("Label 12 Semibold", label),
            ("Caption 11 Medium", caption), ("Micro 10 Semibold", micro)
        ]
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let soft = ShadowStyle(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        static let lifted = ShadowStyle(color: .black.opacity(0.5), radius: 22, x: 0, y: 12)
        static let knob = ShadowStyle(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        static let inner = ShadowStyle(color: Palette.innerShade, radius: 8, x: 0, y: -3)
        static let innerGlow = ShadowStyle(color: Palette.innerGlow, radius: 3, x: 0, y: 1)
        static let focus = ShadowStyle(color: Palette.focusGlow.opacity(0.35), radius: 14, x: 0, y: 0)
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let focus: CGFloat = 1.5
    }

    enum Motion {
        case snappy, smooth, bouncy

        var animation: Animation {
            switch self {
            case .snappy: .spring(response: 0.28, dampingFraction: 0.8)
            case .smooth: .spring(response: 0.5, dampingFraction: 0.88)
            case .bouncy: .spring(response: 0.44, dampingFraction: 0.62)
            }
        }

        func animation(reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: Self.reducedDuration) : animation
        }

        static let reducedDuration: Double = 0.12
        static let staggerStep: Double = 0.04
        static let shimmerDuration: Double = 1.5
        static let shimmerBand: CGFloat = 0.45
    }

    enum Interaction {
        static let hoverScale: CGFloat = 1.04
        static let pressScale: CGFloat = 0.95
        static let subtlePressScale: CGFloat = 0.98
        static let cardHoverScale: CGFloat = 1.02
        static let hoverBrightness: Double = 0.05
        static let pressBrightness: Double = -0.04
        static let hoverHighlight: Double = 0.06
        static let pressHighlight: Double = 0.1
        static let restRim: Double = 0.75
        static let disabledOpacity: Double = 0.4
        static let knobStretch: CGFloat = 1.25
        static let knobHoverScale: CGFloat = 1.06
        static let appearScale: CGFloat = 0.94
        static let appearOffset: CGFloat = 10
        static let screenScale: CGFloat = 0.985
        static let bubbleScale: CGFloat = 0.9
    }

    enum Size {
        static let windowMinWidth: CGFloat = 1100
        static let windowMinHeight: CGFloat = 720
        static let windowDefaultWidth: CGFloat = 1280
        static let windowDefaultHeight: CGFloat = 820
        static let sidebarWidth: CGFloat = 224
        static let sidebarRowHeight: CGFloat = 32
        static let sidebarIcon: CGFloat = 18
        static let titlebarInset: CGFloat = 36
        static let controlHeight: CGFloat = 34
        static let controlHeightSmall: CGFloat = 26
        static let toggleWidth: CGFloat = 42
        static let toggleHeight: CGFloat = 24
        static let toggleKnob: CGFloat = 20
        static let toggleInset: CGFloat = 2
        static let chatColumnWidth: CGFloat = 360
        static let bubbleMaxWidth: CGFloat = 280
        static let attachmentThumb: CGFloat = 56
        static let optionUnitMax: CGFloat = 200
        static let libraryItemMin: CGFloat = 200
        static let libraryPreviewAspect: CGFloat = 4 / 3
        static let emptyIcon: CGFloat = 64
        static let emptyMessageWidth: CGFloat = 280
        static let skeletonLine: CGFloat = 10
        static let skeletonTrailing: CGFloat = 80
        static let settingsMaxWidth: CGFloat = 640
        static let statusDot: CGFloat = 6
        static let swatch: CGFloat = 44
        static let gallerySidebarHeight: CGFloat = 300
        static let galleryColumn: CGFloat = 90
        static let galleryFieldWidth: CGFloat = 280
        static let galleryShimmerWidth: CGFloat = 320
    }
}

extension View {
    func dsShadow(_ style: DS.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
