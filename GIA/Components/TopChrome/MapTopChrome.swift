import SwiftUI

struct MapTopChrome: View {
    let locationContext: LocationContext
    let isMenuExpanded: Bool
    let onMenuTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            LocationContextView(context: locationContext)
                .frame(width: 108, alignment: .leading)
                .accessibilitySortPriority(3)

            Spacer(minLength: 52)

            HamburgerButton(
                isExpanded: isMenuExpanded,
                action: onMenuTap
            )
            .accessibilitySortPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
