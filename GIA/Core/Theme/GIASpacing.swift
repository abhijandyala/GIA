import CoreGraphics

enum GIASpacing {
    static let compactScreenEdge: CGFloat = 18
    static let standardScreenEdge: CGFloat = 22
    static let topChromeInset: CGFloat = 12
    static let topChromeHeight: CGFloat = 44
    static let bottomNavigationHeight: CGFloat = 64
    static let worldBottomClearance: CGFloat = 14

    static func screenEdge(for width: CGFloat) -> CGFloat {
        width <= 375 ? compactScreenEdge : standardScreenEdge
    }
}
