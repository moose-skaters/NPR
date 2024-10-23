#ifndef VOLUMETRIC_CLOUDS_DEF_PS_H
#define VOLUMETRIC_CLOUDS_DEF_PS_H


CBUFFER_START(ShaderVariablesClouds)
    
    int _LowResolutionEvaluation;
    // Quater
    int _EnableIntegration;
    int _SubPixelIndex;
    // BlueNoise
    int _StateFrameIndexMod8;
    float _BlueNoiseIntensity;
    int3 _BlueNoiseDimensions;
    int3 _BlueNoiseModuloMasks;
    float _PowderEffectIntensity;
    float2 _FinalSizeXY;
    float2 _IntermediateSizeXY;
    float2 _TraceSizeXY;

    float _EarthRadius;
    float _CloudLayerBottomAltitude;
    float _CloudLayerThickness;
    float _RayMarchingMaxDistance;
    int _NumPrimarySteps;
    int _NumLightSteps;
    float3 _MinBox;
    float3 _MaxBox;
    float4 _SunLightColor;
    float3 _SunDirection;

    float3 _SunRight;
    float3 _SunUp;
    
    // CloudDensityField
    float2 _WindDirection;

    float _LargeWindSpeed;
    float _MediumWindSpeed;
    float _SmallWindSpeed;

    float4 _CloudMapTiling;
    float3 _BaseShapeNoiseTiling;
    float3 _DetailNoiseTiling;
    float4 _BlueNoiseTiling;
    float _HeightGradientMax;
    float _HeightGradientMin;
    
    float _AltitudeDistortionFirstLayer;
    float _AltitudeDistortionSecondLayer;

    float _ShapeScaleFirstLayer;
    float _ShapeFirstLayerFactor;
    float _ShapeScaleSecondLayer;
    float _ShapeSecondLayerFactor;
    float2 _ShapeNoiseOffset;
    float _VerticalShapeNoiseOffset;
    float _VerticalShapeWindDisplacement;

    float _DetailScale;
    float _ErosionFactorFirstLayer;
    float _ErosionScaleFirstLayer;
    float _ErosionFactorSecondLayer;
    float _ErosionScaleSecondLayer;
    float _ErosionFactorCompensationFirstLayer;
    float _ErosionFactorCompensationSecondLayer;
    float2 _DetailNoiseOffset;
    float _VerticlDetailNoiseOffset;
    float _VerticalErosionWindDisplacement;


    float _SkyTextureScaleKm;
    float4 _SkyTextureScalePerChannel;
    float4 _SkyTexturePlacement;
    float4 _CloudChannelWeight;
    float _CloudCoverage;
    float _CloudDensityFirstLayer;
    float _CloudDensitySecondLayer;
    float _Stormy;
    float3 _StormCloudAlbedo;
    float _AdditiveMaskContribution;
    float4 _AdditiveMaskPerChannelWeight;
    float _AdditiveMaskContribOffset;
    float4 _WindVector;
    float4 _Noise1Scale;
    float _Noise1Speed;
    float _Noise1Mip;
    float _Noise1Bias;
    float _Noise1Strength;

    float4 _Noise2Scale;
    float _Noise2Speed;
    float _DistortMip;
    float _Noise2Bias;
    float _Noise2Strength;

    float4 _Noise3Scale;
    float _Noise3Speed;
    float _Noise3Mip;
    float _Noise3Bias;
    float _Noise3Strength;
    float4 _MultChannel;
    float _MultStrength;

    float _FadeInStart;
    float _FadeInDistance;

    // CloudLighting
    float3 _Albedo;

    float _PhaseG0;
    float _PhaseG1;
    float _PhaseBlendWeight;

    float _MsScattFactor;
    float _MsExtinFactor;
    float _MsPhaseFactor;

    float _AmbientLuminanceIntensity;
    float _SilverIntensity;

    float3 _AmbientLightingTint;
    float _AmbientLightingBottomVisibility;

    float _MaxCloudDistance;

    // CloudReprojection
    float _TemporalAccumulationFactor;
    float _CloudHistoryInvalidation;
    int2 _HistoryViewportSize;
    int2 _HistoryBufferSize;
    float4 _DistanceBasedWeights[12];
    float4x4 _CurVPMatrix;
    float4x4 _PreviousVPMatrix;

    // DepthHeightFog Effect
    int _FogEnabled;
    float4 _ExponentialFogParameters;
    float4 _ExponentialFogParameters3;
    float4 _ExponentialFogColorParameter;
    float4 _FogDirectionalInscatteringColor;
    float4 _FogInscatteringLightDirection;
    float4 _FogDistantSkyLight;

    float  billowy_type_gradient;
    float  wispy_noise_gradient;
    float  CloudType;
    float _CloudFirstLayerdDensityPow;
    float _CloudSecondLayerdDensityPow;
    float _HHFNoiseType;
    float _PackingNoiseChannelBWeight;
    float _PackingNoiseChannelAWeight;
    float _PackingNoiseChannelGWeight;
    float _PackingNoiseChannelRWeight;
    float _HHFNoiseFrequencyHigh;
    float _HHFNoiseFrequencyLow;
CBUFFER_END


#endif
