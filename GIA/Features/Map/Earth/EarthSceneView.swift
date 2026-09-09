import SceneKit
import SwiftUI

struct EarthSceneView: UIViewRepresentable {
    let controller: EarthSceneController
    let isActive: Bool
    let isAnimating: Bool
    let preferredFramesPerSecond: Int
    let isGlobeVisible: Bool

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.scene = controller.scene
        sceneView.pointOfView = controller.pointOfView
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        #if targetEnvironment(simulator)
        sceneView.antialiasingMode = .none
        #else
        sceneView.antialiasingMode = .multisampling4X
        #endif
        sceneView.preferredFramesPerSecond =
            preferredFramesPerSecond
        sceneView.isUserInteractionEnabled = false
        sceneView.accessibilityElementsHidden = true

        updateRenderingState(of: sceneView)
        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        if sceneView.scene !== controller.scene {
            sceneView.scene = controller.scene
        }
        if sceneView.pointOfView !== controller.pointOfView {
            sceneView.pointOfView = controller.pointOfView
        }
        if
            sceneView.preferredFramesPerSecond
                != preferredFramesPerSecond
        {
            sceneView.preferredFramesPerSecond =
                preferredFramesPerSecond
        }

        updateRenderingState(of: sceneView)
    }

    static func dismantleUIView(_ sceneView: SCNView, coordinator: Void) {
        sceneView.isPlaying = false
        sceneView.rendersContinuously = false
        sceneView.scene = nil
    }

    private func updateRenderingState(of sceneView: SCNView) {
        controller.setGlobeVisible(isGlobeVisible)
        controller.setRotationEnabled(
            isActive && isAnimating && isGlobeVisible
        )
        sceneView.isHidden = false
        sceneView.alpha = 1
        sceneView.rendersContinuously = isActive
        sceneView.isPlaying = isActive
        sceneView.setNeedsDisplay()
    }
}
