import SwiftUI

struct HamburgerButton: View {
    let isExpanded: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4.5) {
                line
                line
                line
            }
            .frame(width: 20, height: 20)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(
            isExpanded
                ? "Choose an offline demo action or double tap to close."
                : "Opens presentation controls"
        )
        .accessibilityIdentifier("map.menu")
    }

    private var line: some View {
        Capsule(style: .continuous)
            .fill(
                GIAColor.primaryText.opacity(
                    colorSchemeContrast == .increased ? 1 : 0.84
                )
            )
            .frame(width: 18, height: 1)
    }
}
