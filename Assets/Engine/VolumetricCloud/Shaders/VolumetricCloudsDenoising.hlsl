#ifndef VOLUMETRIC_CLOUDS_DENOISING_H
#define VOLUMETRIC_CLOUDS_DENOISING_H


// Half resolution volumetric cloud texture
TEXTURE2D_X(_VolumetricCloudsTexture);
TEXTURE2D_X(_DepthStatusTexture);

// Clouds data
TEXTURE2D_X(_CloudsLightingTexture);
TEXTURE2D_X(_CloudsDepthTexture);

// Half resolution depth buffer
TEXTURE2D_X(_HalfResDepthBuffer);


// --------------------------------------------------- Reprojection --------------------------------------------------- //

// Given that the sky is virtually a skybox, we cannot use the motion vector buffer
float2 EvaluateCloudMotionVector(float2 NDCxy, float currentCloudDepth, out float3 pixelWorldPos)
{
    // Conver from NDC 0..1 space to WorldSpace
    float3 worldPos = ComputeWorldSpacePosition(NDCxy, currentCloudDepth, UNITY_MATRIX_I_VP);
    pixelWorldPos = worldPos;
    float4 prevClipPos = mul(_PreviousVPMatrix, float4(worldPos, 1.0));
    float4 curClipPos = mul(_CurVPMatrix, float4(worldPos, 1.0));

    float2 previousPositionCS = prevClipPos.xy / prevClipPos.w;
    float2 positionCS = curClipPos.xy / curClipPos.w;

    // Convert from Clip space (-1..1) to NDC 0..1 space
    //float2 velocity = (previousPositionCS - positionCS) * 0.5;
    float2 velocity = (positionCS - previousPositionCS) * 0.5;
    #if UNITY_UV_STARTS_AT_TOP
        velocity.y = -velocity.y;
    #endif

    return velocity;
}

float4 ClipCloudsToRegion(float4 history, float4 minimum, float4 maximum, inout float validityFactor)
{
    // The transmittance is overriden using a clamp
    float clampedTransmittance = clamp(history.w, minimum.w, maximum.w);

    // The lighting is overriden using a clip
    float3 center  = 0.5 * (maximum.xyz + minimum.xyz);
    float3 extents = 0.5 * (maximum.xyz - minimum.xyz);

    // This is actually `distance`, however the keyword is reserved
    float3 offset = history.xyz - center;
    float3 v_unit = offset.xyz / extents.xyz;
    float3 absUnit = abs(v_unit);
    float maxUnit = Max3(absUnit.x, absUnit.y, absUnit.z);

    // We make the history less valid if we had to clip it
    validityFactor *= maxUnit > 1.0 ? 0.5 : 1.0;

    if (maxUnit > 1.0)
        return float4(center + (offset / maxUnit), clampedTransmittance);
    else
        return float4(history.xyz, clampedTransmittance);
}

// Function that fills the struct as we cannot use arrays
void FillCloudReprojectionNeighborhoodData_NOLDS(int2 traceCoord, int subRegionIdx, out NeighborhoodUpsampleData3x3 neighborhoodData)
{
    // Fill the sample data
    neighborhoodData.lowValue0 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(-1, -1));
    neighborhoodData.lowValue1 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(0, -1));
    neighborhoodData.lowValue2 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(1, -1));

    neighborhoodData.lowValue3 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(-1, 0));
    neighborhoodData.lowValue4 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(0, 0));
    neighborhoodData.lowValue5 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(1, 0));

    neighborhoodData.lowValue6 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(-1, 1));
    neighborhoodData.lowValue7 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(0, 1));
    neighborhoodData.lowValue8 = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(1, 1));

    int2 traceTapCoord = traceCoord + int2(-1, -1);
    int checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    int2 representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthA.x = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightA.x = _DistanceBasedWeights[subRegionIdx * 3 + 0].x;

    traceTapCoord = traceCoord + int2(0, -1);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthA.y = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightA.y = _DistanceBasedWeights[subRegionIdx * 3 + 0].y;

    traceTapCoord = traceCoord + int2(1, -1);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthA.z = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightA.z = _DistanceBasedWeights[subRegionIdx * 3 + 0].z;

    traceTapCoord = traceCoord + int2(-1, 0);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthA.w = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightA.w = _DistanceBasedWeights[subRegionIdx * 3 + 0].w;

    traceTapCoord = traceCoord + int2(0, 0);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthB.x = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightB.x = _DistanceBasedWeights[subRegionIdx * 3 + 1].x;

    traceTapCoord = traceCoord + int2(1, 0);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthB.y = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightB.y = _DistanceBasedWeights[subRegionIdx * 3 + 1].y;

    traceTapCoord = traceCoord + int2(-1, 1);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthB.z = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightB.z = _DistanceBasedWeights[subRegionIdx * 3 + 1].z;

    traceTapCoord = traceCoord + int2(0, 1);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthB.w = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightB.w = _DistanceBasedWeights[subRegionIdx * 3 + 1].w;

    traceTapCoord = traceCoord + int2(1, 1);
    checkerBoardIndex = ComputeCheckerBoardIndex(traceTapCoord, _SubPixelIndex);
    representativeCoord = traceTapCoord * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
    neighborhoodData.lowDepthC = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, representativeCoord).x;
    neighborhoodData.lowWeightC = _DistanceBasedWeights[subRegionIdx * 3 + 2].x;

    // In the reprojection case, all masks are valid
    neighborhoodData.lowMasksA = 1.0f;
    neighborhoodData.lowMasksB = 1.0f;
    neighborhoodData.lowMasksC = 1.0f;
}


// --------------------------------------------------- Upscale --------------------------------------------------- //

// Function that fills the struct as we cannot use arrays
void FillCloudUpscaleNeighborhoodData_NOLDS(int2 traceCoord, int subRegionIdx, out NeighborhoodUpsampleData3x3 neighborhoodData)
{
    // Fill the sample data (TOP LEFT)
    float4 lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(-1, -1));
    float3 depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(-1, -1)).xyz; //[sampleCount, sceneDepth, cloudDepth]
    neighborhoodData.lowValue0 = lightingVal;
    neighborhoodData.lowDepthA.x = depthStatusValue.y; 
    neighborhoodData.lowMasksA.x = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightA.x = _DistanceBasedWeights[subRegionIdx * 3 + 0].x;

    // Fill the sample data (TOP CENTER)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(0, -1));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(0, -1)).xyz;
    neighborhoodData.lowValue1 = lightingVal;
    neighborhoodData.lowDepthA.y = depthStatusValue.y;
    neighborhoodData.lowMasksA.y = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightA.y = _DistanceBasedWeights[subRegionIdx * 3 + 0].y;

    // Fill the sample data (TOP RIGHT)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(1, -1));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(1, -1)).xyz;
    neighborhoodData.lowValue2 = lightingVal;
    neighborhoodData.lowDepthA.z = depthStatusValue.y;
    neighborhoodData.lowMasksA.z = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightA.z = depthStatusValue.z;
    neighborhoodData.lowWeightA.z = _DistanceBasedWeights[subRegionIdx * 3 + 0].z;

    // Fill the sample data (MID LEFT)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(-1, 0));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(-1, 0)).xyz;
    neighborhoodData.lowValue3 = lightingVal;
    neighborhoodData.lowDepthA.w = depthStatusValue.y;
    neighborhoodData.lowMasksA.w = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightA.w = _DistanceBasedWeights[subRegionIdx * 3 + 0].w;

    // Fill the sample data (MID CENTER)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(0, 0));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(0, 0)).xyz;
    neighborhoodData.lowValue4 = lightingVal;
    neighborhoodData.lowDepthB.x = depthStatusValue.y;
    neighborhoodData.lowMasksB.x = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightB.x = _DistanceBasedWeights[subRegionIdx * 3 + 1].x;

    // Fill the sample data (MID RIGHT)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(1, 0));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(1, 0)).xyz;
    neighborhoodData.lowValue5 = lightingVal;
    neighborhoodData.lowDepthB.y = depthStatusValue.y;
    neighborhoodData.lowMasksB.y = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightB.y = _DistanceBasedWeights[subRegionIdx * 3 + 1].y;

    // Fill the sample data (BOTTOM LEFT)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(-1, 1));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(-1, 1)).xyz;
    neighborhoodData.lowValue6 = lightingVal;
    neighborhoodData.lowDepthB.z = depthStatusValue.y;
    neighborhoodData.lowMasksB.z = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightB.z = depthStatusValue.z;
    neighborhoodData.lowWeightB.z = _DistanceBasedWeights[subRegionIdx * 3 + 1].z;

    // Fill the sample data (BOTTOM CENTER)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(0, 1));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(0, 1)).xyz;
    neighborhoodData.lowValue7 = lightingVal;
    neighborhoodData.lowDepthB.w = depthStatusValue.y;
    neighborhoodData.lowMasksB.w = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightB.w = depthStatusValue.z;
    neighborhoodData.lowWeightB.w = _DistanceBasedWeights[subRegionIdx * 3 + 1].w;

    // Fill the sample data (BOTTOM CENTER)
    lightingVal = LOAD_TEXTURE2D_X(_VolumetricCloudsTexture, traceCoord + int2(1, 1));
    depthStatusValue = LOAD_TEXTURE2D_X(_DepthStatusTexture, traceCoord + int2(1, 1)).xyz;
    neighborhoodData.lowValue8 = lightingVal;
    neighborhoodData.lowDepthC = depthStatusValue.y;
    neighborhoodData.lowMasksC = saturate(depthStatusValue.x);
    neighborhoodData.lowWeightC = _DistanceBasedWeights[subRegionIdx * 3 + 2].x;
}

float EvaluateUpscaledCloudDepth_NOLDS(int2 halfResCoord, NeighborhoodUpsampleData3x3 nhd)
{
    float finalDepth = 0.0f;
    float sumWeight = 0.0f;

    // Top left
    float weight = (nhd.lowValue0.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksA.x; // 1.0/0.0 * 1.0/0.0
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(-1, -1)).z;
    sumWeight += weight;

    // Top center
    weight = (nhd.lowValue1.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksA.y;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(0, -1)).z;
    sumWeight += weight;

    // Top right
    weight = (nhd.lowValue2.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksA.z;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(1, -1)).z;
    sumWeight += weight;

    // Mid left
    weight = (nhd.lowValue3.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksA.w;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(-1, 0)).z;
    sumWeight += weight;

    // Mid center
    weight = (nhd.lowValue4.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksB.x;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(0, 0)).z;
    sumWeight += weight;

    // Mid right
    weight = (nhd.lowValue5.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksB.y;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(1, 0)).z;
    sumWeight += weight;

    // Bottom left
    weight = (nhd.lowValue6.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksB.z;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(-1, 1)).z;
    sumWeight += weight;

    // Bottom mid
    weight = (nhd.lowValue7.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksB.w;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(0, 1)).z;
    sumWeight += weight;

    // Bottom mid
    weight = (nhd.lowValue8.w != 1.0 ? 1.0 : 0.0) * nhd.lowMasksC;
    finalDepth += weight * LOAD_TEXTURE2D_X(_DepthStatusTexture, halfResCoord + int2(1, 1)).z;
    sumWeight += weight;

    return finalDepth / sumWeight;
}

// This function will return something strictly smaller than 0 if any of the lower res pixels
// have some amound of clouds.
float EvaluateRegionEmptiness(NeighborhoodUpsampleData3x3 data)
{
    float emptyRegionFlag = 1.0f;
    emptyRegionFlag *= lerp(1.0, data.lowValue0.w, data.lowWeightA.x != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue1.w, data.lowWeightA.y != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue2.w, data.lowWeightA.z != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue3.w, data.lowWeightA.w != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue4.w, data.lowWeightB.x != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue5.w, data.lowWeightB.y != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue6.w, data.lowWeightB.z != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue7.w, data.lowWeightB.w != 0.0 ? 1.0 : 0.0);
    emptyRegionFlag *= lerp(1.0, data.lowValue8.w, data.lowWeightC != 0.0 ? 1.0 : 0.0);
    return emptyRegionFlag;
}

#endif // VOLUMETRIC_CLOUDS_DENOISING_H