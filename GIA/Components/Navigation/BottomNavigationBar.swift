import SwiftUI

struct BottomNavigationBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast
    @ScaledMetric(relativeTo: .caption)
    private var minimumHeight = GIASpacing.bottomNavigationHeight

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    GIAColor.subtleStroke.opacity(
                        colorSchemeContrast == .increased ? 1 : 0.55
                    )
                )
                .frame(
                    height: colorSchemeContrast == .increased ? 1 : 0.5
                )

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    navigationButton(for: tab)
                }
            }
            .padding(.horizontal, 18)
            .frame(
                maxWidth: .infinity,
                minHeight: min(minimumHeight - 1, 82)
            )
        }
        .frame(maxWidth: .infinity)
        .background(
            GIAColor.canvas.opacity(reduceTransparency ? 1 : 0.97)
        )
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func navigationButton(for tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Capsule(style: .continuous)
                    .fill(GIAColor.primaryText)
                    .frame(width: 14, height: 1.5)
                    .opacity(isSelected ? 0.82 : 0)

                Image(systemName: tab.symbolName(isSelected: isSelected))
                    .font(
                        .system(
                            size: 17,
                            weight: isSelected ? .semibold : .regular
                        )
                    )
                    .symbolRenderingMode(.monochrome)

                Text(tab.title)
                    .font(GIATypography.navigation)
            }
            .foregroundStyle(
                isSelected
                    ? GIAColor.primaryText
                    : unselectedColor
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("navigation.\(tab.rawValue)")
    }

    private var unselectedColor: Color {
        colorSchemeContrast == .increased
            ? GIAColor.primaryText.opacity(0.76)
            : GIAColor.secondaryText
    }
}
