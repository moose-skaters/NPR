#ifndef UNIVERSAL_FORWARD_UBER_PASS_INCLUDED
#define UNIVERSAL_FORWARD_UBER_PASS_INCLUDED

#include "UberLighting.hlsl"



struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 texcoord1    : TEXCOORD1;
    float4 color        : COLOR;
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float3 positionWS               : TEXCOORD1;
    float3 normalWS                 : TEXCOORD2;
    half4  tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
    float4 color                    : TEXCOORD4;
    float2 uv1                      : TEXCOORD5;
    #if    defined  _SHADERENUM_FACE
    float4 positionSS               : TEXCOORD6;
    float posNDCw                   : TEXCOORD7;
    #endif
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
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.tangentWS = tangentWS;
    
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    output.positionWS = vertexInput.positionWS;
    output.positionCS = vertexInput.positionCS;
    output.color      = input.color;
    output.uv1        = input.texcoord1;

    #if defined   _SHADERENUM_FACE
    output.posNDCw    =  vertexInput.positionNDC.w;
    output.positionSS =  ComputeScreenPos(vertexInput.positionCS);
    
    #endif

    
    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);



    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    float3 mainLightDirection = GetMainLight().direction;
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    #if defined _USESTOCKING_ON
    float fresnel = _fresnelScale*pow(saturate(dot(inputData.normalWS, inputData.viewDirectionWS)), _fresnelIndensity);
    float3 fresnelColor = lerp(_fresnelFallOffColor,_fresnelCenterColor,saturate(fresnel));
    surfaceData.albedo *= fresnelColor;
    #endif
    #if defined _SHADERENUM_HAIR
    float  hairSpecularY =  input.uv1.y -inputData.viewDirectionWS.y *_AnisotropyShift;
    float4 hairSpecular  =  SAMPLE_TEXTURE2D(_HairSpecularMap, sampler_HairSpecularMap, float2(input.uv1.x,hairSpecularY)) *_HairSpecularIntensity * lerp(_HairSpecularColorShadow,_HairSpecularColorLight,saturate(dot(inputData.normalWS,mainLightDirection))) ;
    #endif
    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    #if defined _SHADERENUM_HAIR
    color      += hairSpecular;
    #endif
    #if defined _SHADERENUM_FACE
    float depth = (input.positionCS.z / input.positionCS.w);
    float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
    float2 scrPos = input.positionSS.xy / input.positionSS.w;
    float3 viewLightDir = normalize(TransformWorldToViewDir(mainLightDirection)) / input.posNDCw;
    float2 samplingPoint = scrPos + _HairShadowDistace * viewLightDir.xy;
    float hairDepth = SAMPLE_TEXTURE2D(_HairSoildColor, sampler_HairSoildColor, samplingPoint).g;
    hairDepth = LinearEyeDepth(hairDepth, _ZBufferParams);
    float depthContrast = linearEyeDepth  > hairDepth  + 0.01 ? 0: 1;
    float hairShadow = depthContrast;
    
    float faceSDF = DiffuseFaceLighting(mainLightDirection,input.uv1,hairShadow);
    
    color.rgb = lerp(surfaceData.albedo*_FaceShadowColor,surfaceData.albedo*_FaceLightColor,faceSDF)  + SpecularFaceLighting(mainLightDirection,input.uv1);
    // color = float4(surfaceData.albedo,1);
    #endif
    #if defined _SHADERENUM_EYE
    color = float4(surfaceData.albedo,1);
    #endif
    color.a = _Alpha;

    
    return color;
}

#endif
