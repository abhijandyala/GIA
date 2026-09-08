import SwiftUI

struct MapLayoutMetrics: Equatable {
    let containerSize: CGSize
    let horizontalInset: CGFloat
    let topChromeFrame: CGRect
    let assistantFrame: CGRect
    let worldFrame: CGRect
    let activeGlobeFrame: CGRect

    init(
        containerSize: CGSize,
        topChromeHeight: CGFloat = GIASpacing.topChromeHeight
    ) {
        self.containerSize = containerSize

        let horizontalInset = GIASpacing.screenEdge(for: containerSize.width)
        self.horizontalInset = horizontalInset

        topChromeFrame = CGRect(
            x: horizontalInset,
            y: GIASpacing.topChromeInset,
            width: max(0, containerSize.width - (horizontalInset * 2)),
            height: topChromeHeight
        )

        let worldDiameter = min(
            containerSize.width * 0.80,
            containerSize.height * 0.48
        )
        let worldRadius = worldDiameter / 2
        let desiredWorldCenterY = containerSize.height * 0.53
        let minimumWorldCenterY =
            topChromeFrame.maxY + 24 + worldRadius
        let maximumWorldCenterY =
            containerSize.height
            - GIASpacing.worldBottomClearance
            - worldRadius
        let worldCenterY = min(
            max(desiredWorldCenterY, minimumWorldCenterY),
            max(minimumWorldCenterY, maximumWorldCenterY)
        )

        activeGlobeFrame = CGRect(
            x: (containerSize.width - worldDiameter) / 2,
            y: worldCenterY - worldRadius,
            width: worldDiameter,
            height: worldDiameter
        )

        worldFrame = CGRect(
            origin: .zero,
            size: containerSize
        )
        assistantFrame = activeGlobeFrame.insetBy(dx: -60, dy: -60)
    }
}

struct MapStage<
    World: View,
    Chrome: View,
    Assistant: View,
    Overlay: View
>: View {
    @ScaledMetric(relativeTo: .caption)
    private var topChromeHeight = GIASpacing.topChromeHeight

    private let world: World
    private let chrome: Chrome
    private let assistant: Assistant
    private let overlay: Overlay

    init(
        @ViewBuilder world: () -> World,
        @ViewBuilder chrome: () -> Chrome,
        @ViewBuilder assistant: () -> Assistant,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.world = world()
        self.chrome = chrome()
        self.assistant = assistant()
        self.overlay = overlay()
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = MapLayoutMetrics(
                containerSize: proxy.size,
                topChromeHeight: topChromeHeight
            )

            ZStack(alignment: .topLeading) {
                world
                    .frame(
                        width: metrics.worldFrame.width,
                        height: metrics.worldFrame.height
                    )
                    .position(
                        x: metrics.worldFrame.midX,
                        y: metrics.worldFrame.midY
                    )

                chrome
                    .frame(
                        width: metrics.topChromeFrame.width,
                        height: metrics.topChromeFrame.height
                    )
                    .position(
                        x: metrics.topChromeFrame.midX,
                        y: metrics.topChromeFrame.midY
                    )

                assistant
                    .frame(
                        width: metrics.assistantFrame.width,
                        height: metrics.assistantFrame.height
                    )
                    .position(
                        x: metrics.assistantFrame.midX,
                        y: metrics.assistantFrame.midY
                    )

                overlay
                    .frame(
                        width: metrics.containerSize.width,
                        height: metrics.containerSize.height
                    )
                    .position(
                        x: metrics.containerSize.width / 2,
                        y: metrics.containerSize.height / 2
                    )
            }
            .frame(
                width: metrics.containerSize.width,
                height: metrics.containerSize.height
            )
            .clipped()
            .coordinateSpace(name: "mapStage")
        }
    }
}
