import SceneKit
import UIKit

final class EarthSceneController {
    let scene: SCNScene
    var pointOfView: SCNNode { cameraNode }
    private(set) var visualState: GIAVoiceVisualState

    private let earthPresentationNode = SCNNode()
    private let earthTiltNode = SCNNode()
    private let earthSurfaceNode: SCNNode
    private let earthMaterial: SCNMaterial
    private let cameraNode: SCNNode
    private var transformationProgress: Float
    private var presentationProgress: Float
    private var speechIntensity: Float = 0

    init() {
        scene = SCNScene()
        let earthSurface = Self.makeEarthSurface()
        earthSurfaceNode = earthSurface.node
        earthMaterial = earthSurface.material
        cameraNode = Self.makeCameraNode()

        let initialProgress = Self.debugInitialTransformationProgress
        let initialSpeechIntensity = Self.debugInitialSpeechIntensity
        transformationProgress = initialProgress
        presentationProgress = initialProgress >= 1 ? 1 : 0
        speechIntensity = initialSpeechIntensity
        if initialSpeechIntensity > 0 {
            visualState = .speaking
        } else if initialProgress >= 1 {
            visualState = .listening
        } else if initialProgress > 0 {
            visualState = .activating
        } else {
            visualState = .world
        }

        configureScene()
        configureVoiceShader()
        startIdleRotation()
    }

    func setGlobeVisible(_ isVisible: Bool) {
        earthPresentationNode.isHidden = !isVisible
        earthPresentationNode.opacity = isVisible ? 1 : 0
        earthSurfaceNode.isHidden = !isVisible
    }

    func setRotationEnabled(_ isEnabled: Bool) {
        earthSurfaceNode.isPaused = !isEnabled
    }

    func handleMemoryPressure(isActive: Bool) {
        earthSurfaceNode.removeAllAudioPlayers()
        earthPresentationNode.removeAllAudioPlayers()
        if !isActive {
            stopVoiceActions()
            setRotationEnabled(false)
            SCNTransaction.flush()
        }
    }

    func setFocusedPresentation(
        _ isFocused: Bool,
        animated: Bool
    ) {
        earthPresentationNode.removeAction(forKey: "gia.presentation")

        let target: Float = isFocused ? 1 : 0
        if animated, !isFocused {
            animatePresentation(to: target)
            return
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration =
            animated
            ? EarthRenderingConfiguration.presentationDuration
            : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
            controlPoints: 0.42,
            0,
            0.58,
            1
        )
        applyPresentationProgress(target)
        SCNTransaction.commit()
    }

    func activate() {
        stopVoiceActions()
        visualState = .activating

        animateTransformation(to: 1) { [weak self] in
            self?.visualState = .listening
        }
    }

    func runSimulatedVoiceDemo() {
        stopVoiceActions()
        visualState = .activating

        animateTransformation(to: 1) { [weak self] in
            guard let self else { return }

            self.visualState = .listening
            let beginSpeaking = SCNAction.sequence([
                .wait(
                    duration:
                        EarthRenderingConfiguration
                        .simulatedListeningDuration
                ),
                .run { [weak self] _ in
                    self?.startSimulatedSpeech()
                }
            ])
            self.earthSurfaceNode.runAction(
                beginSpeaking,
                forKey: "gia.demoSequence"
            )
        }
    }

    func setSpeechIntensity(_ value: Float) {
        earthSurfaceNode.removeAction(forKey: "gia.simulatedSpeech")
        let normalizedValue = min(max(value, 0), 1)

        guard transformationProgress > 0.98 else {
            return
        }

        visualState =
            normalizedValue > 0.015 ? .speaking : .pause
        applySpeechIntensity(normalizedValue)
    }

    func pauseSpeaking() {
        earthSurfaceNode.removeAction(forKey: "gia.simulatedSpeech")
        visualState = .pause
        animateSpeechIntensity(to: 0)
    }

    func returnToWorld() {
        stopVoiceActions()
        visualState = .returningToWorld
        captureInFlightPresentation()
        animateSpeechIntensity(to: 0)

        let wipeDuration = max(
            0.01,
            EarthRenderingConfiguration.transformationDuration
                * Double(abs(transformationProgress))
        )
        let zoomDelay =
            wipeDuration
            * EarthRenderingConfiguration.worldZoomDelayFactor

        animateTransformation(to: 0)
        animatePresentation(
            to: 0,
            delay: zoomDelay
        ) { [weak self] in
            self?.visualState = .world
        }
    }

    func setActiveWithoutMotion(_ isActive: Bool) {
        stopVoiceActions()
        applySpeechIntensity(0)
        applyTransformationProgress(isActive ? 1 : 0)
        applyPresentationProgress(isActive ? 1 : 0)
        visualState = isActive ? .listening : .world
    }

    private func configureVoiceShader() {
        earthMaterial.shaderModifiers = [
            .geometry: EarthVoiceShader.geometry,
            .surface: EarthVoiceShader.surface
        ]
        applyTransformationProgress(transformationProgress)
        applySpeechIntensity(speechIntensity)
    }

    private func animateTransformation(
        to target: Float,
        completion: (() -> Void)? = nil
    ) {
        earthSurfaceNode.removeAction(forKey: "gia.transformation")

        let startingProgress = transformationProgress
        let distance = abs(target - startingProgress)
        let duration = max(
            0.01,
            EarthRenderingConfiguration.transformationDuration
                * Double(distance)
        )
        let action = SCNAction.customAction(
            duration: duration
        ) { [weak self] _, elapsedTime in
            guard let self else { return }

            let linearProgress = min(
                max(Float(Double(elapsedTime) / duration), 0),
                1
            )
            let easedProgress = Self.smootherStep(linearProgress)
            let value = startingProgress
                + ((target - startingProgress) * easedProgress)
            self.applyTransformationProgress(value)
        }

        earthSurfaceNode.runAction(
            action,
            forKey: "gia.transformation",
            completionHandler: { [weak self] in
                self?.applyTransformationProgress(target)
                completion?()
            }
        )
    }

    private func animatePresentation(
        to target: Float,
        delay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) {
        earthPresentationNode.removeAction(forKey: "gia.presentation")
        captureInFlightPresentation()

        let startingProgress = presentationProgress
        let distance = abs(target - startingProgress)
        let zoomDuration = max(
            0.01,
            EarthRenderingConfiguration.worldPresentationDuration
                * Double(distance)
        )
        let totalDuration = delay + zoomDuration
        let action = SCNAction.customAction(
            duration: totalDuration
        ) { [weak self] _, elapsedTime in
            guard let self else { return }

            let zoomElapsed = max(
                0,
                Double(elapsedTime) - delay
            )
            let linearProgress = min(
                max(Float(zoomElapsed / zoomDuration), 0),
                1
            )
            let easedProgress = Self.easeInOutQuad(linearProgress)
            self.applyPresentation(
                scaleProgress: startingProgress
                    + ((target - startingProgress) * easedProgress),
                offsetProgress: startingProgress
                    + ((target - startingProgress) * easedProgress),
                fieldOfViewProgress: startingProgress
                    + ((target - startingProgress) * easedProgress),
                interpolateScaleLogarithmically: true
            )
        }

        earthPresentationNode.runAction(
            action,
            forKey: "gia.presentation",
            completionHandler: { [weak self] in
                self?.applyPresentationProgress(target)
                completion?()
            }
        )
    }

    private func captureInFlightPresentation() {
        let presentedNode = earthPresentationNode.presentation
        let presentedScale = presentedNode.scale.x

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        earthPresentationNode.scale = presentedNode.scale
        earthPresentationNode.position = presentedNode.position
        if let camera = cameraNode.camera {
            camera.fieldOfView =
                cameraNode.presentation.camera?.fieldOfView
                ?? camera.fieldOfView
        }
        SCNTransaction.commit()

        presentationProgress = Self.presentationProgress(
            fromScale: presentedScale
        )
    }

    private func applyPresentationProgress(_ value: Float) {
        applyPresentation(
            scaleProgress: value,
            offsetProgress: value,
            fieldOfViewProgress: value,
            interpolateScaleLogarithmically: false
        )
    }

    private func applyPresentation(
        scaleProgress: Float,
        offsetProgress: Float,
        fieldOfViewProgress: Float,
        interpolateScaleLogarithmically: Bool
    ) {
        let clampedScale = min(max(scaleProgress, 0), 1)
        let clampedOffset = min(max(offsetProgress, 0), 1)
        let clampedFieldOfView = min(max(fieldOfViewProgress, 0), 1)
        presentationProgress = clampedScale
        let scale =
            interpolateScaleLogarithmically
            ? Self.mixLog(
                EarthRenderingConfiguration.worldScale,
                EarthRenderingConfiguration.focusedScale,
                clampedScale
            )
            : Self.mix(
                EarthRenderingConfiguration.worldScale,
                EarthRenderingConfiguration.focusedScale,
                clampedScale
            )
        let verticalOffset = Self.mix(
            EarthRenderingConfiguration.worldVerticalOffset,
            EarthRenderingConfiguration.focusedVerticalOffset,
            clampedOffset
        )

        earthPresentationNode.scale = SCNVector3(
            scale,
            scale,
            scale
        )
        earthPresentationNode.position = SCNVector3(
            0,
            verticalOffset,
            0
        )
        cameraNode.camera?.fieldOfView =
            interpolateScaleLogarithmically
            ? Self.mixLog(
                EarthRenderingConfiguration.worldFieldOfView,
                EarthRenderingConfiguration.focusedFieldOfView,
                Double(clampedFieldOfView)
            )
            : Self.mix(
                EarthRenderingConfiguration.worldFieldOfView,
                EarthRenderingConfiguration.focusedFieldOfView,
                Double(clampedFieldOfView)
            )
    }

    private func animateSpeechIntensity(to target: Float) {
        earthSurfaceNode.removeAction(forKey: "gia.speechSmoothing")

        let startingIntensity = speechIntensity
        let duration =
            target > startingIntensity
            ? EarthRenderingConfiguration.speechAttackDuration
            : EarthRenderingConfiguration.speechReleaseDuration
        let action = SCNAction.customAction(
            duration: duration
        ) { [weak self] _, elapsedTime in
            guard let self else { return }

            let linearProgress = min(
                max(Float(Double(elapsedTime) / duration), 0),
                1
            )
            let easedProgress = Self.smootherStep(linearProgress)
            let value = startingIntensity
                + ((target - startingIntensity) * easedProgress)
            self.applySpeechIntensity(value)
        }

        earthSurfaceNode.runAction(
            action,
            forKey: "gia.speechSmoothing"
        )
    }

    private func startSimulatedSpeech() {
        visualState = .speaking
        earthSurfaceNode.removeAction(forKey: "gia.speechSmoothing")

        let duration =
            EarthRenderingConfiguration.simulatedSpeakingDuration
        let action = SCNAction.customAction(
            duration: duration
        ) { [weak self] _, elapsedTime in
            guard let self else { return }

            let time = Double(elapsedTime)
            let attack = Self.smoothStep(
                edge0: 0,
                edge1: 0.28,
                value: time
            )
            let release = 1 - Self.smoothStep(
                edge0: duration - 0.82,
                edge1: duration,
                value: time
            )
            let phraseMovement =
                0.48
                + (0.16 * sin(time * 2.1))
                + (0.10 * sin((time * 4.7) + 0.8))
                + (0.06 * sin((time * 8.3) + 1.7))
            let emphasis = pow(
                max(0, sin((time * 1.55) - 0.35)),
                6
            ) * 0.26
            let signal = Float(
                min(
                    max((phraseMovement + emphasis) * attack * release, 0),
                    1
                )
            )

            self.applySpeechIntensity(signal)
        }

        earthSurfaceNode.runAction(
            action,
            forKey: "gia.simulatedSpeech"
        ) { [weak self] in
            guard let self else { return }
            self.visualState = .pause
            self.animateSpeechIntensity(to: 0)
        }
    }

    private func stopVoiceActions() {
        earthSurfaceNode.removeAction(forKey: "gia.demoSequence")
        earthSurfaceNode.removeAction(forKey: "gia.simulatedSpeech")
        earthSurfaceNode.removeAction(forKey: "gia.transformation")
        earthSurfaceNode.removeAction(forKey: "gia.speechSmoothing")
        earthPresentationNode.removeAction(forKey: "gia.presentation")
    }

    private func applyTransformationProgress(_ value: Float) {
        transformationProgress = min(max(value, 0), 1)
        earthMaterial.setValue(
            NSNumber(value: transformationProgress),
            forKey: "giaTransformationProgress"
        )
    }

    private func applySpeechIntensity(_ value: Float) {
        speechIntensity = min(max(value, 0), 1)
        earthMaterial.setValue(
            NSNumber(value: speechIntensity),
            forKey: "giaSpeechIntensity"
        )
    }

    private func configureScene() {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(
            white: 0.46,
            alpha: 1
        )
        scene.lightingEnvironment.intensity = 1.15

        earthPresentationNode.name = "earth.presentation"
        earthTiltNode.name = "earth.tilt"
        earthTiltNode.eulerAngles.z = Self.radians(fromDegrees: -23.4)
        earthTiltNode.addChildNode(earthSurfaceNode)
        earthPresentationNode.addChildNode(earthTiltNode)
        scene.rootNode.addChildNode(earthPresentationNode)
        setFocusedPresentation(false, animated: false)

        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(Self.makeKeyLightNode())
        scene.rootNode.addChildNode(Self.makeRimLightNode())
        scene.rootNode.addChildNode(Self.makeAmbientLightNode())
    }

    private func startIdleRotation() {
        let rotation = SCNAction.rotateBy(
            x: 0,
            y: -.pi * 2,
            z: 0,
            duration: EarthRenderingConfiguration.idleRotationDuration
        )
        rotation.timingMode = .linear

        earthSurfaceNode.runAction(
            .repeatForever(rotation),
            forKey: "earth.idleRotation"
        )
    }

    private static func makeEarthSurface() -> (
        node: SCNNode,
        material: SCNMaterial
    ) {
        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount =
            EarthRenderingConfiguration.sphereSegmentCount

        let material = SCNMaterial()
        material.name = "earth.surface"
        material.lightingModel = .physicallyBased
        material.diffuse.contents =
            UIImage(named: "EarthTexture")
            ?? UIColor(red: 0.04, green: 0.12, blue: 0.20, alpha: 1)
        material.diffuse.magnificationFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.mipFilter = .linear
        material.diffuse.maxAnisotropy = 16
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.roughness.contents = 0.88
        material.metalness.contents = 0.0

        sphere.firstMaterial = material

        let node = SCNNode(geometry: sphere)
        node.name = "earth.surface"
        node.eulerAngles.y = radians(fromDegrees: -18)
        return (node, material)
    }

    private static func makeCameraNode() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.projectionDirection = .horizontal
        camera.zNear = 0.05
        camera.zFar = 100
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.08
        camera.contrast = 0.12
        camera.saturation = 0.88

        let node = SCNNode()
        node.name = "earth.camera"
        node.camera = camera
        node.position = SCNVector3(0, 0, 3.40)
        return node
    }

    private static func makeKeyLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1_650
        light.temperature = 6_200
        light.castsShadow = false

        let node = SCNNode()
        node.name = "earth.keyLight"
        node.light = light
        node.eulerAngles = SCNVector3(
            radians(fromDegrees: -24),
            radians(fromDegrees: -38),
            0
        )
        return node
    }

    private static func makeRimLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.intensity = 55
        light.color = UIColor(white: 0.54, alpha: 1)
        light.castsShadow = false

        let node = SCNNode()
        node.name = "earth.rimLight"
        node.light = light
        node.eulerAngles = SCNVector3(
            radians(fromDegrees: 18),
            radians(fromDegrees: 142),
            0
        )
        return node
    }

    private static func makeAmbientLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 220
        light.color = UIColor(white: 0.72, alpha: 1)

        let node = SCNNode()
        node.name = "earth.ambientLight"
        node.light = light
        return node
    }

    private static func radians(fromDegrees degrees: Float) -> Float {
        degrees * .pi / 180
    }

    private static func smootherStep(_ value: Float) -> Float {
        let value = min(max(value, 0), 1)
        return value * value * value
            * (value * ((value * 6) - 15) + 10)
    }

    private static func easeInOutQuad(_ value: Float) -> Float {
        let value = min(max(value, 0), 1)
        if value < 0.5 {
            return 2 * value * value
        }

        let inverted = (-2 * value) + 2
        return 1 - ((inverted * inverted) / 2)
    }

    private static func mix(
        _ from: Float,
        _ to: Float,
        _ progress: Float
    ) -> Float {
        from + ((to - from) * progress)
    }

    private static func mix(
        _ from: Double,
        _ to: Double,
        _ progress: Double
    ) -> Double {
        from + ((to - from) * progress)
    }

    private static func mixLog(
        _ from: Float,
        _ to: Float,
        _ progress: Float
    ) -> Float {
        let from = max(from, 0.0001)
        let to = max(to, 0.0001)
        return from * pow(to / from, progress)
    }

    private static func mixLog(
        _ from: Double,
        _ to: Double,
        _ progress: Double
    ) -> Double {
        let from = max(from, 0.0001)
        let to = max(to, 0.0001)
        return from * pow(to / from, progress)
    }

    private static func presentationProgress(
        fromScale scale: Float
    ) -> Float {
        let world = EarthRenderingConfiguration.worldScale
        let focused = EarthRenderingConfiguration.focusedScale
        let span = focused - world
        guard abs(span) > 0.0001 else {
            return 0
        }

        return min(max((scale - world) / span, 0), 1)
    }

    private static func smoothStep(
        edge0: Double,
        edge1: Double,
        value: Double
    ) -> Double {
        guard edge1 > edge0 else {
            return value >= edge1 ? 1 : 0
        }

        let normalized = min(
            max((value - edge0) / (edge1 - edge0), 0),
            1
        )
        return normalized * normalized * (3 - (2 * normalized))
    }

    private static var debugInitialTransformationProgress: Float {
        #if DEBUG
        guard
            let rawValue = ProcessInfo.processInfo.environment[
                "GIA_TRANSFORMATION_PROGRESS"
            ],
            let value = Float(rawValue)
        else {
            return 0
        }

        return min(max(value, 0), 1)
        #else
        return 0
        #endif
    }

    private static var debugInitialSpeechIntensity: Float {
        #if DEBUG
        guard
            let rawValue = ProcessInfo.processInfo.environment[
                "GIA_SPEECH_INTENSITY"
            ],
            let value = Float(rawValue)
        else {
            return 0
        }

        return min(max(value, 0), 1)
        #else
        return 0
        #endif
    }
}
