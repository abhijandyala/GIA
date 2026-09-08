import SceneKit

enum EarthVoiceShader {
    static let geometry = """
    #pragma arguments
    float giaTransformationProgress;
    float giaSpeechIntensity;

    #pragma body
    float progress = clamp(giaTransformationProgress, 0.0, 1.0);
    float speech = clamp(giaSpeechIntensity, 0.0, 1.0);
    float3 unitPosition = normalize(_geometry.position.xyz);
    float4 viewVertex =
        scn_node.modelViewTransform * float4(unitPosition, 1.0);

    float3 directionA = normalize(float3(0.82, 1.08, 0.54));
    float3 directionB = normalize(float3(-0.46, 0.72, 1.16));
    float3 directionC = normalize(float3(1.04, -0.38, 0.68));

    float phaseA =
        dot(unitPosition, directionA) * 5.2
        - scn_frame.time * 0.82;
    float phaseB =
        dot(unitPosition, directionB) * 7.4
        + scn_frame.time * 0.61;
    float phaseC =
        dot(unitPosition, directionC) * 10.6
        - scn_frame.time * 1.48;

    float broadWave = sin(phaseA);
    float secondaryWave = sin(phaseB);
    float speechWave = sin(phaseC);

    float organicOffset =
        sin(dot(unitPosition, float3(2.7, 4.1, 3.2)) * 2.15
            + scn_frame.time * 0.38) * 0.014
        + sin(dot(unitPosition, float3(-3.3, 1.9, 4.4)) * 1.7
            - scn_frame.time * 0.27) * 0.006;

    float diagonalPosition = clamp(
        0.5 + 0.25 * (viewVertex.x - viewVertex.y),
        0.0,
        1.0
    );
    float threshold = mix(-0.14, 1.14, progress);
    float signedFrontDistance =
        diagonalPosition + organicOffset - threshold;
    float transformedMask = 1.0 - smoothstep(
        -0.040,
        0.040,
        signedFrontDistance
    );
    float transitionBand = 1.0 - smoothstep(
        0.020,
        0.080,
        abs(signedFrontDistance)
    );

    float ambientDisplacement =
        0.0062 * broadWave
        + 0.0031 * secondaryWave;
    float speechDisplacement =
        speech * (
            0.0145 * speechWave
            + 0.0080 * broadWave
            + 0.0045 * secondaryWave
        );
    float frontPhase =
        (phaseC * 0.72) + (scn_frame.time * 0.9);
    float frontDisplacement =
        transitionBand
        * (
            0.0038 * sin(frontPhase)
            + 0.0015 * sin(
                (phaseB * 0.58) - (scn_frame.time * 0.44)
            )
        );

    float displacement =
        transformedMask
        * (ambientDisplacement + speechDisplacement)
        + frontDisplacement;
    float threeDimensionalInfluence =
        1.0 - smoothstep(0.62, 1.0, progress);
    displacement *= threeDimensionalInfluence;
    displacement = clamp(displacement, -0.035, 0.035);

    float3 waveGradient =
        directionA * cos(phaseA) * 5.2 * 0.0062
        + directionB * cos(phaseB) * 7.4 * 0.0031
        + speech * (
            directionC * cos(phaseC) * 10.6 * 0.0145
            + directionA * cos(phaseA) * 5.2 * 0.0080
            + directionB * cos(phaseB) * 7.4 * 0.0045
        )
        + transitionBand * (
            directionC * cos(frontPhase) * 7.632 * 0.0038
            + directionB
                * cos((phaseB * 0.58) - (scn_frame.time * 0.44))
                * 4.292
                * 0.0015
        );
    waveGradient -=
        unitPosition * dot(waveGradient, unitPosition);

    _geometry.position.xyz += _geometry.normal * displacement;
    _geometry.normal = normalize(
        _geometry.normal
        - waveGradient
            * transformedMask
            * threeDimensionalInfluence
    );
    _geometry.texcoords[0] +=
        float2(broadWave, secondaryWave)
        * transitionBand
        * 0.0035;
    """

    static let surface = """
    #pragma arguments
    float giaTransformationProgress;

    #pragma body
    float progress = clamp(giaTransformationProgress, 0.0, 1.0);
    float3 surfaceNormal = normalize(_surface.normal);

    float organicOffset =
        sin(dot(surfaceNormal, float3(2.7, 4.1, 3.2)) * 2.15
            + scn_frame.time * 0.38) * 0.014
        + sin(dot(surfaceNormal, float3(-3.3, 1.9, 4.4)) * 1.7
            - scn_frame.time * 0.27) * 0.006;

    float diagonalPosition = clamp(
        0.5 + 0.25 * (_surface.position.x - _surface.position.y),
        0.0,
        1.0
    );
    float threshold = mix(-0.14, 1.14, progress);
    float signedFrontDistance =
        diagonalPosition + organicOffset - threshold;
    float transformedMask = 1.0 - smoothstep(
        -0.040,
        0.040,
        signedFrontDistance
    );
    float transitionBand = 1.0 - smoothstep(
        0.020,
        0.080,
        abs(signedFrontDistance)
    );

    float3 earthColor = _surface.diffuse.rgb;
    float earthLuminance = dot(
        earthColor,
        float3(0.2126, 0.7152, 0.0722)
    );
    float3 drainedEarth = mix(
        earthColor,
        float3(earthLuminance),
        transitionBand * 0.42
    );
    float3 obsidian = float3(0.009, 0.011, 0.014);

    _surface.diffuse.rgb = mix(
        drainedEarth,
        obsidian,
        transformedMask
    );
    _surface.roughness = mix(
        _surface.roughness,
        0.95,
        transformedMask
    );
    _surface.metalness = mix(
        _surface.metalness,
        0.0,
        transformedMask
    );
    _surface.specular = mix(
        _surface.specular,
        float4(0.015, 0.016, 0.018, 1.0),
        transformedMask
    );
    """

}
