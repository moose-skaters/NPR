#ifndef UNIVERSAL_FORWARD_UBER_OUTLINE_PASS_INCLUDED
#define UNIVERSAL_FORWARD_UBER_OUTLINE_PASS_INCLUDED

#include "UberLighting.hlsl"



struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float4 color        : COLOR;
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;


    float3 positionWS               : TEXCOORD1;


    float3 normalWS                 : TEXCOORD2;

    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign



   
    
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;


    inputData.positionWS = input.positionWS;


    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    inputData.tangentToWorld = tangentToWorld;
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
    
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;
    
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    inputData.fogCoord = 0;
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

   
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassOutlineVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    float3 normalVS = TransformWorldToViewDir(normalInput.normalWS,true);
    float3 viewDir = normalize(vertexInput.positionVS) * 0.01;
    float outlineFactor = GenShinGetOutlineCameraFovAndDistanceFixMultiplier(vertexInput.positionVS.z,input.color.a,_OutlineScaleFactor,_OutlineWidth,_OutlineAdj01,_OutlineAdj02);
    float3 OffsetPositionVS = ApplyOutlineOffsetViewSpace(vertexInput.positionVS,viewDir,_OutlineZOffset,normalVS,outlineFactor);
    
    // already normalized from normal transform to WS.
    
    output.positionCS = TransformWViewToHClip(OffsetPositionVS);

    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassOutlineFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    half4 color = 0;
    color.a     = 1;
    return color;
}

#endif
