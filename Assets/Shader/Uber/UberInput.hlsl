#ifndef UNIVERSAL_UBER_INPUT_INCLUDED
#define UNIVERSAL_UBER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"




// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _DetailAlbedoMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _Parallax;
half _OcclusionStrength;
half _ClearCoatMask;
half _ClearCoatSmoothness;
half _DetailAlbedoMapScale;
half _DetailNormalMapScale;
half _Surface;
half _EmissionScale;
half _RampMin;
half _RampMax;
half _AnisotropyShift;
half _HairSpecularIntensity;
half4 _HairSpecularColorShadow;
half4 _HairSpecularColorLight;
float _fresnelScale;
float _fresnelIndensity;
float3 _fresnelFallOffColor;
float3 _fresnelCenterColor;


float3 _HeadRight;
float3 _HeadFoward;
float  _FaceShadowOffset;
float  _FaceShadowSoftness;
float3 _FaceLightColor;
float3 _FaceShadowColor;
float  _NoseSpecMin;
float  _NoseSpecMax;
float3 _FaceSpecularColor;
float  _HairShadowDistace;

half4 _OutlineAdj01;
half4 _OutlineAdj02;
half _OutlineWidth;
half _OutlineScaleFactor;
half _OutlineZOffset;
CBUFFER_END

TEXTURE2D(_RMOTex);            SAMPLER(sampler_RMOTex);
TEXTURE2D(_RampMap);           SAMPLER(sampler_RampMap);
TEXTURE2D(_HairSpecularMap);   SAMPLER(sampler_HairSpecularMap);
TEXTURE2D(_SDFMap);            SAMPLER(sampler_SDFMap);
TEXTURE2D(_HairSoildColor);    SAMPLER(sampler_HairSoildColor);


inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = albedoAlpha.a;
    clip(albedoAlpha.a - 0.2);
    half4 specGloss = SAMPLE_TEXTURE2D(_RMOTex, sampler_RMOTex, uv);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = specGloss.g * _Metallic;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.smoothness = (1-specGloss.r) *_Smoothness;
    half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
    
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = specGloss.b;
    outSurfaceData.occlusion = LerpWhiteTo(outSurfaceData.occlusion,_OcclusionStrength);
    outSurfaceData.emission = specGloss.a * outSurfaceData.albedo * _EmissionScale;

    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
}

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED
