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



half4 _OutlineAdj01;
half4 _OutlineAdj02;
half _OutlineWidth;
half _OutlineScaleFactor;
half _OutlineZOffset;
CBUFFER_END

TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_RampTex);            SAMPLER(sampler_RampTex);



real3 UnpackNormalGBA(real4 packedNormal, real scale = 1.0)
{
    real3 normal;
    normal.y = 1 - packedNormal.y;
    normal.x = packedNormal.x * packedNormal.a;
    normal.xy = normal.xy * 2.0 - 1.0;
    normal.z = max(1.0e-16, sqrt(1.0 - saturate(dot(normal.xy, normal.xy))));
    normal.xy *= scale;
    return normal;
}

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = albedoAlpha.a;
   clip(albedoAlpha.a - 0.2);
    half4 specGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
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
