import SwiftUI

struct LocationContextView: View {
    let context: LocationContext

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var body: some View {
        Text(context.primaryLabel)
            .font(GIATypography.location)
            .tracking(2.1)
            .foregroundStyle(
                GIAColor.primaryText.opacity(
                    colorSchemeContrast == .increased ? 1 : 0.82
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current location")
            .accessibilityValue(context.accessibilityLabel)
            .accessibilityIdentifier("map.location")
    }
}
