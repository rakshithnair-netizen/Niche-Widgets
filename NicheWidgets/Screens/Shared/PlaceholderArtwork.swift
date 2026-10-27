import SwiftUI

struct PlaceholderArtwork: View {
    let seed: Int

    var body: some View {
        let colors = DS.Palette.artwork[abs(seed) % DS.Palette.artwork.count]
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            EllipticalGradient(
                colors: [DS.Palette.artworkHighlight, .clear],
                center: UnitPoint(x: 0.22, y: 0.18),
                startRadiusFraction: 0,
                endRadiusFraction: 0.75
            )
        }
    }
}
