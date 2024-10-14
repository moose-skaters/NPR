#ifndef UNIVERSAL_FACE_INPUT_INCLUDED
#define UNIVERSAL_FACE_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"




// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;

half4 _OutlineAdj01;
half4 _OutlineAdj02;
half  _OutlineWidth;
half  _OutlineScaleFactor;
half  _OutlineZOffset;
CBUFFER_END



#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED
