#ifndef UNIVERSAL_UBER_LIGHTING_CORE
#define UNIVERSAL_UBER_LIGHTING_CORE
#include "UberInput.hlsl"
//-------------------------------Outline Start-----------------------------------//
float GetCameraFOV()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    float t = unity_CameraProjection._m11;
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
    return fov;
}
float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    //make outline "fadeout" if character is too small in camera's view
    return saturate(inputMulFix);
}
//平行光沿着Y轴旋转
half DiffuseFaceLighting(half3 BaseColor,half3 L,half2 uv,half shadow)
{
    half3 diffuseColor = (half3)0;
    half3 headRight = normalize(_HeadRight);
    half3 headForward = normalize(_HeadFoward);
    half3 headUp = cross(headForward,headRight);
    half3 fixedDirectionWS = normalize(L - dot(L,headUp) * headUp);
    // half2 sdfUV = half2(sign(dot(fixedDirectionWS,headRight)),1) * half2(-1,1) * uv;
    half sign_sdf = sign(dot(fixedDirectionWS,headRight));
    half2 sdfUV = sign_sdf > 0 ? uv : half2(1 - uv.x,uv.y);
    // sdfUV = uv;
    half sdfValue = SAMPLE_TEXTURE2D(_SDFMap,sampler_SDFMap,sdfUV).r;
    sdfValue += _FaceShadowOffset;
    half sdfThreshold = 1 - (dot(fixedDirectionWS,headForward) * 0.5 +0.5);
    half sdf = smoothstep(sdfThreshold - _FaceShadowSoftness,sdfThreshold + _FaceShadowSoftness,sdfValue);
    sdf = saturate(sdf * shadow);
    return sdf;
}
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    float cameraMulFix;
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case
        ////////////////////////////////

        // keep outline similar width on screen accoss all camera distance       
        cameraMulFix = abs(positionVS_Z);

        // can replace to a tonemap function if a smooth stop is needed
        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);
        cameraMulFix = pow(cameraMulFix,0.5);

        // keep outline similar width on screen accoss all camera fov
        cameraMulFix *= clamp(GetCameraFOV(),15,45);    //clamp fov   
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case
        ////////////////////////////////
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 100; // 100 is a magic number to match perspective camera's outline width
    }

    return cameraMulFix * 0.000002; // mul a const to make return result = default normal expand amount WS
}

float4 ClipPosZOffset(float4 positionCS, float viewSpaceZOffset)
{
    if(unity_OrthoParams.w != 0)
    {
        positionCS.z -= viewSpaceZOffset * 0.0002;
        return positionCS;
    }
    float modifiedPositionVS_Z = - positionCS.w - viewSpaceZOffset;

    float modifiedPositionCS_Z = modifiedPositionVS_Z * UNITY_MATRIX_P[2].z + UNITY_MATRIX_P[2].w;

    positionCS.z = modifiedPositionCS_Z * positionCS.w / (-modifiedPositionVS_Z);

    return positionCS;
}

half RemapOutline(half x, half t1, half t2, half s1, half s2)
{
    return saturate((x - t1) /  max(0.00100000005,(t2 - t1))) * (s2 - s1) + s1;
}

float GenShinGetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z,float vertexColorA,float outlineScaleFactor,float outlineWidth,float4 outlineDistanceAdjust,float4 outlineScaleAdjust)
{
    float fovfactor = 2.41400003 / unity_CameraProjection._m11;
    float fovAndDepthFactor = fovfactor * - positionVS_Z;
    float4 outlineAdjValue = 0;
    outlineAdjValue.xy = fovAndDepthFactor < outlineDistanceAdjust.y ? outlineDistanceAdjust.xy : outlineDistanceAdjust.yz;
    outlineAdjValue.zw = fovAndDepthFactor < outlineDistanceAdjust.y ? outlineScaleAdjust.xy : outlineScaleAdjust.yz;
    
    fovfactor = RemapOutline(fovAndDepthFactor,outlineAdjValue.x,outlineAdjValue.y,outlineAdjValue.z,outlineAdjValue.w);
    float tempScaleFactor = outlineScaleFactor;
    fovfactor = tempScaleFactor * fovfactor;
    fovfactor = 100 * fovfactor;
    fovfactor = outlineWidth * fovfactor;
    fovfactor = 0.414250195 * fovfactor;
    fovfactor = vertexColorA * fovfactor;
    float outlineFactor = fovfactor;
    return outlineFactor;
}

float3 ApplyOutlineOffsetViewSpace(float3 positionVS,float3 viewDir,float outlineZOffset,float3 normalVS,float outlineFactor)
{
    float3 offsetPositionVS = 0;
    offsetPositionVS = positionVS + viewDir * outlineZOffset;
    offsetPositionVS.xy = offsetPositionVS.xy + normalVS.xy * outlineFactor;
    return offsetPositionVS;
}

//-------------------------------Outline End-----------------------------------//

#endif
