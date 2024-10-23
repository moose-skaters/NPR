#ifndef VOLUMETRIC_CLOUDS_SHADOWS_PS_H
#define VOLUMETRIC_CLOUDS_SHADOWS_PS_H

#include "./VolumetricCloudsDefPS.hlsl"
#include "./VolumetricCloudsUtilitiesPS.hlsl"

TEXTURE2D(_VolumetricCloudsShadow); // Output _VolumetricCloudsShadow

void EvaluateVolumetricCloudsShadow(uint2 currentCoords, out float transmittance)
{
    // First we compute the location of the shadow plane in the planet coordinate system
    float3 shadowPlaneOrigin = _SunDirection.xyz * (_CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius);
    float3 shadowPlaneNormal = -_SunDirection.xyz;

    // Here the plane is guaranteed to intersect, we don't need to test the result
    float t;
    IntersectPlane(float3(0, 0, 0), _SunDirection.xyz, shadowPlaneOrigin, shadowPlaneNormal, t);

    // #ifdef LOCAL_VOLUMETRIC_CLOUD
    float3 shadowCookieCenterWS = float3(_WorldSpaceShadowCenter.x, _ShadowPlaneHeightOffset, _WorldSpaceShadowCenter.z) + t * _SunDirection.xyz;
    //float3 shadowCookieCenterWS = float3(_WorldSpaceShadowCenter.xyz) + t * _SunDirection.xyz;

    // Compute the normalized coordinate on the shadow plane [-1, 1]
    float2 normalizedCoord = (currentCoords.xy - _ShadowCookieResolution * 0.5f) / (_ShadowCookieResolution * 0.5f);

    // Compute the origin of the ray properties in the planet space || shadowCookieWS
    float3 rayOriginWS = (normalizedCoord.x * _SunRight.xyz * _ShadowRegionSize.x + normalizedCoord.y * _SunUp.xyz * _ShadowRegionSize.y) + shadowCookieCenterWS;
    float3 rayDirection = -_SunDirection.xyz;

    // Compute the attenuation
    transmittance = 1.0f;

    // (shadowCookieWS + sunDirection) Intersect the outer|inner sphere
    float2 intersectionO, intersectionI;
    int numIntersectionO = RaySphereIntersection(rayOriginWS, rayDirection, _CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius, intersectionO);
    int numIntersectionI = RaySphereIntersection(rayOriginWS, rayDirection, _CloudLayerBottomAltitude + _EarthRadius, intersectionI);

    if (numIntersectionO != 0 && numIntersectionI != 0)
    {
        // Compute the integration range
        float startDistance = intersectionO.x;
        float totalDistance = intersectionI.x - intersectionO.x;

        float stepSize = totalDistance / 16;
        for (int i = 0; i < 16; i++)
        {
            // Compute the sphere intersection position
            float3 positionWS = rayOriginWS + rayDirection * (intersectionO.x + stepSize * i);

            // Compute the cloud density
            CloudProperties cloudProperties;
            EvaluateCloudPropertiesUETest(currentPositionWS, cloudProperties);

            if (cloudProperties.cloudDensity > CLOUD_DENSITY_TRESHOLD)
            {
                // Apply the extinction
                float SafeExtinctionThreshold = 1e-6f;
                float SafeExtinctionCoefficients = max(SafeExtinctionThreshold, cloudProperties.cloudDensity * cloudProperties.sigmaT);
                const float3 currentStepTransmittance= max(exp(-SafeExtinctionCoefficients * stepSize), exp(-SafeExtinctionCoefficients * stepSize * 0.25) * 0.7);
                transmittance *= currentStepTransmittance;
            }
        }
    }

    transmittance = lerp(1.0 - _ShadowOpacity, 1.0, transmittance);
}

float2 CloudShadowWorldSpaceToUV(in float3 TranslatedWorldPosition, in float4x4 CloudShadowmapTranslatedWorldToLightClipMatrix, inout float z)
{
    float4 ClipSpace = mul(CloudShadowmapTranslatedWorldToLightClipMatrix, float4(TranslatedWorldPosition, 1.0f));
    ClipSpace /= ClipSpace.wwww;
    z = ClipSpace.z;
    float2 UVs = ClipSpace.xy;
    // Todo
    return UVs;
}

float GetCloudVolumetricShadow(in float3 TranslatedWorldPosition, in float4x4 CloudShadowmapTranslatedWorldToLightClipMatrix)
{
    
}


#endif