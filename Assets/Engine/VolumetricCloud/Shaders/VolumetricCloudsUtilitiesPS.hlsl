#ifndef VOLUMETRIC_CLOUD_UTILITIES_PS_H
#define VOLUMETRIC_CLOUD_UTILITIES_PS_H

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "./VolumetricCloudsDefPS.hlsl"

// Unit Convert
#define KILOMETER_TO_METER 1000
#define METER_TO_KILOMETER 0.001
// Multi scattering approximation based on http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf
// 1 is for the default single scattering look. Then [2,N] is for extra "octaves"
#define MSCOUNT 3
// Density blow wich we consider the density is zero (optimization reasons)
#define CLOUD_DENSITY_TRESHOLD 0.001f
// Transmittance blow wich we consider the energy is absorbed (optimization reasons)
#define CLOUD_TRANSMITTANCE_TRESHOLD 0.003
// Number of steps before we start the large steps
#define EMPTY_STEPS_BEFORE_LARGE_STEPS 8
// Maximal size of a light step
#define LIGHT_STEP_MAXIMAL_SIZE 1000.0f
// Value that is used to normalize the noise textures
#define NOISE_TEXTURE_NORMALIZATION_FACTOR 100000.0f
// Global offset to the high frequency noise
#define CLOUD_DETAIL_MIP_OFFSET 0.0
// Global offset for reaching the LUT/AO
#define CLOUD_LUT_MIP_OFFSET 1.0
// Distance until which the erosion texture i used
#define MIN_EROSION_DISTANCE 3000.0
#define MAX_EROSION_DISTANCE 1000000.0
// Maximal distance until which the "skybox"
#define MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE 200000.0f
#define _SkyAtmosphereBottomRadiusKm 6360
#define _SkyAtmosphereTopRadiusKm 6420

// Cloud description tables
SAMPLER(s_linear_repeat_sampler);
SAMPLER(s_trilinear_repeat_sampler);
SAMPLER(s_linear_clamp_sampler);

TEXTURE2D(_CloudMapTexture); 
TEXTURE2D(_CloudLutTexture);  //SAMPLER(s_linear_clamp_sampler);
TEXTURE2D(_ClouTypeTexture);
TEXTURE2D(_CumulusLutPresetMap);  //SAMPLER(s_linear_clamp_sampler);
TEXTURE2D(_AltoStratusLutPresetMap);
TEXTURE2D(_CumulonimbusLutPresetMap);
TEXTURE2D(_AdditiveMaskTexture); 
TEXTURE2D(_CloudBrushMapTextureAdd);
TEXTURE2D(_CloudBrushMapTextureSubtract);

// Noise textures for adding details
TEXTURE3D(_PerlinWorley128RGBA);
TEXTURE3D(_Worley128RGBA);
TEXTURE3D(_Worley32RGBA); 
TEXTURE2D(_BlueNoise2D); 
TEXTURE3D(_ErosionNoise);
TEXTURE3D(_DetailFBMNoise);

// Atmosphere tables
TEXTURE2D(_TransmittanceLutTexture); //SAMPLER(s_linear_clamp_sampler); 

// Prepare
TEXTURE2D(_HalfResolutionDepthCheckerboardMinMaxTexture);
// Full resolution depth buffer
TEXTURE2D_X(_FullResDepthBuffer);

// sigmaE,sigmaS, TrToLight for the multiple scattering
struct ParticipatingMediaContext
{
	float3 ScatteringCoefficients[MSCOUNT];
	float3 ExtinctionCoefficients[MSCOUNT];
	float3 TransmittanceToLight0[MSCOUNT];
};

// Phase functions for the multiple scattering
struct ParticipatingMediaPhaseContext
{
	float Phase0[MSCOUNT];
};

struct EnvironmentLighting
{
    float3 sunDirection;
    float3 sunColor0; // the sunlight at the start point
    float3 sunColor1; // the sunlight at the end point
    float cosAngle; // cos angle between the light and the ray direction

    float3 ambientTermTop;
    float3 ambientTermBottom;

    // Phase functions for the multiple scattering
    ParticipatingMediaPhaseContext cloudPMPC;
};

struct CloudRay 
{
    // Depth value of the pixel
    float depthValue;
    // Origin of the ray in world space
    float3 originWS;
    // Direction of the ray in world space
    float3 direction;
    // Maximal ray length before hitting the far plane or an occluder
    float maxRayLength;
    // Flag to track if we are inside the cloud layers
    float insideClouds;
    // Distance to earth center 
    float toEarthCenterLength;
    // Integration Noise
    float integrationNoise;
    // Environement lighting
    EnvironmentLighting envLighting;

};

struct RayMarchRange
{
    // The start of the range in KiloMeter
    float start;
    // The length of the range in KiloMeter
    float distance;
};

struct CloudCoverageData
{
    // From a top down view, in what proportions this pixel has clouds
    float2 coverage;
    // From a top down view, in what proportions this pixel has clouds
    float rainClouds;
    // Value that allows us to request the cloudtype using the density
    float cloudType;
    // Maximal cloud height
    float maxCloudHeight;
};

struct CloudLutData
{
    // CloudType-HeightBased density
    float density;
    // CloudType-HeightBased erosion
    float erosion;
    // CloudType-HeightBased ambientOcclusion
    float ambientOcclusion;
};

struct CloudProperties
{
    // Normalized float that tells the "amount" of clouds that is at a given location
    float cloudDensity;
    // Ambient occlusion for the ambient probe
    float ambientOcclusion;
    // Normalized value that tells us the height within the cloud volume (vertically)
    float normalizedHeight;
    // ExtictionCof of the cloud
    float sigmaT;
};

// Structure that holds the result of our volumetric ray
struct VolumetricRayResult
{
    // Amount of lighting that comes from the clouds
    float3 inScattering;
    // Transmittance through the clouds
    float transmittanceToView;
    // Mean distance of the clouds
    float meanDistance;
    // Flag that defines if the ray is valid or not
    bool invalidRay;
};

// -------------------------------------------- Common Functions -------------------------------------------- //
// positonPS = positonWS + float3(0.0, _EarthRadius, 0.0);
float EvaluateNormalizedHeightInCloudArea(float3 positionPS)
{
    return (length(positionPS) - (_CloudLayerBottomAltitude + _EarthRadius)) / _CloudLayerThickness;
}

bool PointInsideCloudVolume(float3 positionPS)
{
    float distanceToEarthCenter = length(positionPS);
    return distanceToEarthCenter > (_CloudLayerBottomAltitude + _EarthRadius) && 
           distanceToEarthCenter < (_CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius);
}

float Remap(float value, float oldMin, float oldMax, float newMin, float newMax)
{
    return (((value - oldMin) / (oldMax - oldMin)) * (newMax - newMin)) + newMin;
}
float PowderEffect(float cloudDensity, float cosAngle, float intensity)
{
    float powderEffect = 1.0 - exp(-cloudDensity * 4.0);
    powderEffect = saturate(powderEffect * 2.0);
    return lerp(1.0, lerp(1.0, powderEffect, smoothstep(0.5, -0.5, cosAngle)), intensity);
}
// Function that interects a ray with a sphere (optimized for very large sphere), returns up to two positives distances.
int RaySphereIntersection(float3 startWS, float3 dir, float radius, out float2 result)
{
    float3 startPS = startWS + float3(0, _EarthRadius, 0);
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, startPS);
    float c = dot(startPS, startPS) - (radius * radius);
    float d = (b*b) - 4.0*a*c;
    result = 0.0;
    int numSolutions = 0;
    if (d >= 0.0)
    {
        // Compute the values required for the solution eval
        float sqrtD = sqrt(d);
        float q = -0.5*(b + FastSign(b) * sqrtD);
        result = float2(c/q, q/a);
        // Remove the solutions we do not want
        numSolutions = 2;
        if (result.x < 0.0)
        {
            numSolutions--;
            result.x = result.y;
        }
        if (result.y < 0.0)
            numSolutions--;
    }
    // Return the number of solutions
    return numSolutions;
}

// Function that interects a ray with a sphere (optimized for very large sphere), and says if there is at least one intersection
bool RaySphereIntersection(float3 startWS, float3 dir, float radius)
{
    float3 startPS = startWS + float3(0, _EarthRadius, 0);
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, startPS);
    float c = dot(startPS, startPS) - (radius * radius);
    float d = (b * b) - 4.0 * a * c;
    bool flag = false;
    if (d >= 0.0)
    {
        // Compute the values required for the solution eval
        float sqrtD = sqrt(d);
        float q = -0.5 * (b + FastSign(b) * sqrtD);
        float2 result = float2(c/q, q/a);
        flag = result.x > 0.0 || result.y > 0.0;
    }
    return flag;
}

// This function compute the checkerboard undersampling position
int ComputeCheckerBoardIndex(int2 traceCoord, int subPixelIndex)
{
    int localOffset = (traceCoord.x & 1 + traceCoord.y & 1) & 1;
    int checkerBoardLocation = (subPixelIndex + localOffset) & 0x3;
    return checkerBoardLocation;
}

// CheckerBoardIndex(0,1,2,3) > (0,0) | (1,0) | (0,1) | (1,1)
uint2 HalfResolutionIndexToOffset(uint index)
{
    return uint2(index & 0x1, index / 2);
}

float BlueNoiseScalar(uint2 ScreenCoord, uint FrameIndex)
{
    // pixelCoord & 127; FrameIndex & 63;
    uint3 WrappedCoordinate = uint3(ScreenCoord, FrameIndex) & _BlueNoiseModuloMasks; // WrappedCoord to (127, 127, 63)
    uint3 TextureCoordinate = uint3(WrappedCoordinate.x, WrappedCoordinate.z * _BlueNoiseDimensions.y + WrappedCoordinate.y, 0);
    return LOAD_TEXTURE2D(_BlueNoise2D, uint2(TextureCoordinate.xy)).x;
}

// BuildRay in IntermediateCoorSpace
CloudRay BuildRay(uint2 intermediateCoord)
{
    CloudRay ray;
    ZERO_INITIALIZE(CloudRay, ray);

    // Current Tracing Pixel's screenUV
    float2 uv; 
    uint2 screenCoord;
    if (_LowResolutionEvaluation && _EnableIntegration)
    {
        intermediateCoord = min(intermediateCoord, _IntermediateSizeXY.xy - 1);
        uv = float2((intermediateCoord.xy + 0.5) / _IntermediateSizeXY); // interCoord = halfRes
        screenCoord = intermediateCoord * 2;
    }
    else 
    {
        intermediateCoord = min(intermediateCoord, _FinalSizeXY.xy - 1);
        uv = float2((intermediateCoord.xy + 0.5) / _FinalSizeXY); // interCoord = fullRes
        screenCoord = intermediateCoord;
    }
    
    // Keep track of the integration noise
    ray.integrationNoise = _LowResolutionEvaluation ? BlueNoiseScalar(screenCoord, _StateFrameIndexMod8) : 0.0;

    // Trace up to furthest depth.
    if (_LowResolutionEvaluation && _EnableIntegration)
    {
        ray.depthValue = LOAD_TEXTURE2D_X(_HalfResolutionDepthCheckerboardMinMaxTexture, intermediateCoord).r; // QuaterRes Case, intermedateCoord = HalfRes
    } 
    else 
    {
        ray.depthValue = LOAD_TEXTURE2D_X(_FullResDepthBuffer, intermediateCoord).r; // FullRes Case|HalfRes Case, intermedateCoord = FullRes
    }

    // Flag is this sky pixel occluded by an object?
    
    float isOccluded = ray.depthValue != UNITY_RAW_FAR_CLIP_VALUE ? 1.0 : 0.0;
   
    // Compute the position of the point from which the ray will start
    ray.originWS = _WorldSpaceCameraPos.xyz;
    
    // normalize to get the direction
    float3 worldPos = ComputeWorldSpacePosition(uv, ray.depthValue, UNITY_MATRIX_I_VP);
    float3 worldPosToOrigin = worldPos - ray.originWS;
    
    ray.direction = normalize(worldPosToOrigin);

    // Compute the max cloud ray length
#ifdef LOCAL_VOLUMETRIC_CLOUDS
    ray.maxRayLength = lerp(_ProjectionParams.z, length(worldPosToOrigin), isOccluded);
#else
    ray.maxRayLength = lerp(MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE, length(worldPosToOrigin), isOccluded);
#endif

    // Compute the distance to the center of the earth
    ray.toEarthCenterLength = length(ray.originWS + float3(0, _EarthRadius, 0)); 

    // Evaluate where the point is
    // -2.0 means under the surface of the earth
    // -1.0 means between the surface of the earth and the lower cloud bound
    // 0.0 means inside the cloud domain
    // 1.0 means above the cloud domain
    if (ray.toEarthCenterLength < _EarthRadius)
        ray.insideClouds = -2.0;
    else if (ray.toEarthCenterLength <= (_CloudLayerBottomAltitude + _EarthRadius))
        ray.insideClouds = -1.0;
    else if (ray.toEarthCenterLength > (_CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius))
        ray.insideClouds = 1.0f;
    else
        ray.insideClouds = 0.0;

    return ray;
}


bool GetCloudVolumeIntersection(float3 originWS, float3 dir, float insideClouds, float toEarthCenterLength, out RayMarchRange rayMarchRange)

{
    // Zero-Initialize
    ZERO_INITIALIZE(RayMarchRange, rayMarchRange);

    // intersect with all three spheres
    float2 intersectionInter, intersectionOuter;
    int numInterInner = RaySphereIntersection(originWS, dir, _CloudLayerBottomAltitude + _EarthRadius, intersectionInter);
    int numInterOuter = RaySphereIntersection(originWS, dir, _CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius, intersectionOuter);
    bool intersectEarth = RaySphereIntersection(originWS, dir, insideClouds < -1.5 ? toEarthCenterLength : _EarthRadius);

    // Did we achieve any intersection ?
    bool intersect = numInterInner > 0 || numInterOuter > 0;

    // -2.0 means under the surface of the earth
    // -1.0 means between the surface of the earth and the lower cloud bound
    // 0.0 means inside the cloud domain
    // 1.0 means above the cloud domain
    
    // If we are inside the lower cloud bound
    if (insideClouds < -0.5)
    {
        // The ray starts at the first intersection with the lower bound and goes up to the first intersection with the outer bound
        rayMarchRange.start = intersectionInter.x;
        rayMarchRange.distance = intersectionOuter.x - intersectionInter.x;
    }
    else if (insideClouds == 0.0)
    {
        // If we are inside, the ray always starts at 0
        rayMarchRange.start = 0;

        // if we intersect the earth, this means the ray has only one range
        if (intersectEarth)
            rayMarchRange.distance = intersectionInter.x;
        // if we do not untersect the earth and the lower bound. This means the ray exits to outer space
        else if(numInterInner == 0)
            rayMarchRange.distance = intersectionOuter.x;
        // If we do not intersect the earth, but we do intersect the lower bound, we have two ranges.
        else
            rayMarchRange.distance = intersectionInter.x;
    }
    // We are in outer space
    else
    {
        // We always start from our intersection with the outer bound
        rayMarchRange.start = intersectionOuter.x;

        // If we intersect the earth, ony one range
        if(intersectEarth)
            rayMarchRange.distance = intersectionInter.x - intersectionOuter.x;
        else
        {
            // If we do not intersection the lower bound, the ray exits from the upper bound
            if(numInterInner == 0)
                rayMarchRange.distance = intersectionOuter.y - intersectionOuter.x;
            else
                rayMarchRange.distance = intersectionInter.x - intersectionOuter.x;
        }
    }

    // Make sure we cannot go beyond what the number of samples
    rayMarchRange.distance = clamp(0, rayMarchRange.distance, _RayMarchingMaxDistance);

    // UserSetting Distance from the point of view 
    // rayMarchRange.start = min(_TracingStartMaxDistance, rayMarchRange.start);

    // Return if we have an intersection
    return intersect;
}


float DensityFadeValue(float distanceToCamera)
{
    return saturate((distanceToCamera - _FadeInStart) / (_FadeInStart + _FadeInDistance));
}

// ---------------------------------------- HillsideCloudDensityField --------------------------------------------------// 
float4 GetCloudWind()
{
    float3 windVector = _WindVector.xyz;

    float cloudLayoutTextureSize = 1024.0;
    float cloudLayoutTextureScale = cloudLayoutTextureSize / _SkyTextureScaleKm;
    cloudLayoutTextureScale *= 1000.0;
    float4 windVector_with_time = float4(windVector, _Time.y / cloudLayoutTextureScale);
    return windVector_with_time;
}

float GetGlobalDensityControl()
{
    float _DensityOffest = 0.0;
    float densityControl = _DensityOffest + _CloudDensityFirstLayer;
    float densityControlMul = densityControl * 1.5;
    return lerp(densityControl, densityControlMul, _Stormy);
}

float3 GetSkyTextureScaleAndPlacement(float3 positionKm, inout float3 skyPlacement)
{
    float3 uvw = float3(positionKm.x / _SkyTextureScaleKm, positionKm.y / _SkyTextureScaleKm, positionKm.z / _SkyTextureScaleKm);
    uvw = float3(uvw.x + 0.5, uvw.y + 0.0, uvw.z + 0.5);
    // Rotate UW
    float _SkyRotationOffset = 0;
    float rotationOffset = _SkyRotationOffset + _SkyTexturePlacement.w;
    uvw = float3(uvw.x * cos(rotationOffset) - uvw.z * sin(rotationOffset), 
                 uvw.y, 
                 uvw.x * sin(rotationOffset) + uvw.z * cos(rotationOffset));
    // Placement
    float3 _SkyPlacementOffest = float3(0.0, 0.0, 0.0);
    float3 uvwOffset = float3(_SkyTexturePlacement.x + _SkyPlacementOffest.x, _SkyTexturePlacement.y + _SkyPlacementOffest.y, _SkyTexturePlacement.z + _SkyPlacementOffest.z);
    uvw = uvw - uvwOffset;
    skyPlacement = uvwOffset;
    return uvw;
}

float3 GetCloudAlbedo(float cloudExtictionCof)
{
    float exCof3 = cloudExtictionCof * cloudExtictionCof * cloudExtictionCof;
    float lerpWeight = (1.0 - exCof3) * _Stormy;
    float3 albedo = lerp(_Albedo, _StormCloudAlbedo, lerpWeight);
    return albedo;
}

float GetCloudExtictionCofUETest(float3 positionWS, float normalizedHeight)
{
    float3 positionWSKm = positionWS * METER_TO_KILOMETER;
    float globalCoverageControl = _CloudCoverage;
    float globalDensity = _CloudDensityFirstLayer;
    float3 skyPlacement;
    float3 skyTextureScale = GetSkyTextureScaleAndPlacement(positionWSKm, skyPlacement); 
    // ---------------------- Sample Cloud Profiles by Layout Texture ---------------------- //
    // CloudPattern (R = Stratocumulus, G = Altostratus, B = Cirrostratus, and A = Nimbostratus)
    float2 skyTextureUV = float2(skyTextureScale.x - 0.5, skyTextureScale.z - 0.5);

    float4 cloudMapData = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, skyTextureUV, 0).rgba;
    float cloud1 = cloudMapData.r;
    float cloud2 = cloudMapData.g;
    float cloud3 = cloudMapData.b;
    float cloud4 = cloudMapData.a;

    float4 skyTexture = float4(cloud1, cloud2, cloud3, cloud4);
    float3 skyTextureRGBWithWeight = float3(skyTexture.x * _CloudChannelWeight.x,  skyTexture.y * _CloudChannelWeight.y, skyTexture.z * _CloudChannelWeight.z);
    float skyTextureValueMax = max(max(skyTextureRGBWithWeight.x, skyTextureRGBWithWeight.y), skyTextureRGBWithWeight.z);
    // Weight By 2D Cloud Texture -> select the max value
    float skyTextureWeightForVolumeNoise = lerp(skyTextureValueMax, skyTexture.w, _Stormy);
    // Profile
    
    float2 profileUV1 = float2(normalizedHeight, cloud1);
    float2 profileUV2 = float2(normalizedHeight, cloud2);
    float2 profileUV3 = float2(normalizedHeight, cloud3);
    float2 profileUV4 = float2(normalizedHeight, cloud4);

    float profile1 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV1, 0).r;
    float profile2 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV2, 0).g;
    float profile3 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV3, 0).b;
    float profile4 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV4, 0).a;
    float4 profileTexture = float4(profile1, profile2, profile3, profile4);
    float3 profileRGBWithWeight = float3(profileTexture.x * _CloudChannelWeight.x, profileTexture.y * _CloudChannelWeight.y, profileTexture.z * _CloudChannelWeight.z);
    float profileAWithWeight = profileTexture.w * _CloudChannelWeight.w;
    float profileTextureValueMax = max(max(profileRGBWithWeight.x, profileRGBWithWeight.y), profileRGBWithWeight.z);
    float profileValue = lerp(profileTextureValueMax, profileAWithWeight, _Stormy);
    // Blend Profiles + Volume Noise -> select the max value
    float profilesBlendValueForVolumeNoise = profileValue - 0.5; // [-0.5, +0.5]
    // ----------------------------------------- Wind --------------------------------------- //

    // cloudWind = (windvector, _Time.y / (_CloudTextureSize / _CloudTextureScaleKm * 1000.0))
    float4 cloudWind = GetCloudWind();
    float3 wind = float3(cloudWind.x * cloudWind.w, cloudWind.y * cloudWind.w, cloudWind.z * cloudWind.w);
    // -------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise2(Distortion) -------------------------------------------- //
    float3 noise2WindOffset = wind * _Noise2Speed;
    float3 noise2UVW = float3(skyTextureScale.x * _Noise2Scale.x, skyTextureScale.y * _Noise2Scale.y, skyTextureScale.z * _Noise2Scale.z);
    noise2UVW += noise2WindOffset; 
    float noise2 = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise2UVW, 0).r; // Perlin-Worley
    noise2 -= _Noise2Bias;
    noise2 *= lerp(_Noise2Strength, _Noise2Strength * 3.0, _Stormy);

    float3 distortUVW = float3( (normalizedHeight * (1 - 0.05) + 0.05), 
                                (abs((normalizedHeight * (1 - 0.05) + 0.05) - 0.5) * 2.0) * (abs((normalizedHeight * (1 - 0.05) + 0.05) - 0.5) * 2.0), 
                                (normalizedHeight * (1 - 0.05) + 0.05));
    // For Add to Noise1UVW
    distortUVW *= noise2;
    // ---------------------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise1 -------------------------------------------- //
    float3 noise1WindOffset = wind * _Noise1Speed;
    float3 noise1UVW = float3(skyTextureScale.x * _Noise1Scale.x, skyTextureScale.y * _Noise1Scale.y, skyTextureScale.z * _Noise1Scale.z);
    noise1UVW += noise1WindOffset;
    // Add DistortUVW to Noise1UVW
    noise1UVW += distortUVW;
    float noise1 = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise1UVW, 0).g; // Worley
    noise1 -= _Noise1Bias;
    noise1 += globalCoverageControl;
    // For Combine Noise3 MultChannel
    noise1 *= _Noise1Strength;
    // ---------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise3 -------------------------------------------- //
    float3 noise3WindOffset = wind * _Noise3Speed;
    float3 noise3UVW = float3(skyTextureScale.x * _Noise3Scale.x, skyTextureScale.y * _Noise3Scale.y, skyTextureScale.z * _Noise3Scale.z);
    noise3UVW += noise3WindOffset;
    float3 noise3Tex = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise3UVW, 0).rgb;// rgb Perlin-Worley | Worley1 | Worley2
    float3 noise3Tex4 = SAMPLE_TEXTURE3D_LOD(_Worley32RGBA, s_trilinear_repeat_sampler, noise3UVW, 0).rgb;
    // Todo: MultChannel Mask
    //float noise3Weight = dot(noise3Tex.rgb, _MultChannel.rgb); // r
    float noise3Weight = noise3Tex.r;
    noise3Weight = lerp(noise3Weight, noise3Tex.g, _Stormy); // g
    // For Combine Noise3 MultChannel
    noise3Weight *= _MultStrength;
    // For Add Noise3
    float noise3Add = noise3Tex.b - _Noise3Bias + noise3Tex4.b * 0.0; // b
    noise3Add += globalCoverageControl;
    noise3Add *= _Noise3Strength;

    // ---------------------------------------------------------------------------------------- //
    // --------------------------------------- Additive Mask -------------------------------------------- //
    // Add additive mask
    float2 additiveMaskUV = float2(skyTextureScale.x + skyPlacement.x, skyTextureScale.z + skyPlacement.z);
    float3 maskTex = SAMPLE_TEXTURE2D_LOD(_AdditiveMaskTexture, s_linear_repeat_sampler, additiveMaskUV, 0).rgb;
    float3 maskTexWithAMPCWeight = float3(  maskTex.x * _AdditiveMaskPerChannelWeight.x, 
                                            maskTex.y * _AdditiveMaskPerChannelWeight.y, 
                                            maskTex.z * _AdditiveMaskPerChannelWeight.z);
    float3 maskTexWithCPPCWeight = float3(  maskTexWithAMPCWeight.x * _CloudChannelWeight.x, 
                                            maskTexWithAMPCWeight.y * _CloudChannelWeight.y, 
                                            maskTexWithAMPCWeight.z * _CloudChannelWeight.z);
    float maskAdd = max(max(maskTexWithCPPCWeight.x, maskTexWithCPPCWeight.y), maskTexWithCPPCWeight.z) * (_AdditiveMaskContribOffset + _AdditiveMaskContribution) * 0.01;

    // ---------------------------------------------------------------------------------------- //
    // --------------------------------------- Output -------------------------------------------- //
    // 1 Combine Noise3 MultChannel
    noise1 *= noise3Weight;
    // 2 Add Noise3
    noise1 += noise3Add;
    // 3 Blend Profiles + Volume Noise
    noise1 += profilesBlendValueForVolumeNoise;
    // 4 Weight By 2D Cloud Texture
    noise1 *= skyTextureWeightForVolumeNoise;
    // 5 Add additive mask
    noise1 += maskAdd;
    // 6 Global Density
    noise1 *= globalDensity;
    // 7 Fade Near Camera Weight

    
    float3 camPosition = _WorldSpaceCameraPos.xyz;
    float fncWeight = distance(camPosition, positionWS);

    //fncWeight = DensityFadeValue(fncWeight);

    fncWeight *= 0.00002;
    fncWeight = saturate(fncWeight);
    noise1 *= fncWeight;

/*
    float3 camPosition = _WorldSpaceCameraPos.xyz;
    float fncWeight = distance(camPosition, positionWS);
    float weight = saturate((fncWeight - _FadeInStart) / (_FadeInStart + _FadeInDistance));
    noise1 *= weight;*/

    // 8 Prevent Shadowing from Above Clouds
    /*
    float preventSFAC;
    if (normalizedHeight > 0.5)
    {
        preventSFAC = 0.0;
    } 
    else if (normalizedHeight == 0.5)
    {
        preventSFAC = 1.0;
    } 
    else
    {
        preventSFAC = 0.0;
    }
    noise1 *= preventSFAC;*/

    // 9 Saturate | density * sigmaT


    return saturate(noise1 * normalizedHeight);

}

float GetCloudExtictionCofUE(float3 positionWS, float normalizedHeight)
{
    float3 positionWSKm = positionWS * METER_TO_KILOMETER;
    float globalCoverageControl = _CloudCoverage;
    float globalDensity = _CloudDensityFirstLayer;
    float3 skyPlacement;
    float3 skyTextureScale = GetSkyTextureScaleAndPlacement(positionWSKm, skyPlacement); 
    // ---------------------- Sample Cloud Profiles by Layout Texture ---------------------- //
    // CloudPattern (R = Stratocumulus, G = Altostratus, B = Cirrostratus, and A = Nimbostratus)
    float2 skyTextureUV = float2(skyTextureScale.x - 0.5, skyTextureScale.z - 0.5);
    float2 uv1 = skyTextureUV * _SkyTextureScalePerChannel.x;
    float2 uv2 = skyTextureUV * _SkyTextureScalePerChannel.y;
    float2 uv3 = skyTextureUV * _SkyTextureScalePerChannel.z;
    float2 uv4 = skyTextureUV * _SkyTextureScalePerChannel.w;
    float cloud1 = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, uv1, 0).r;
    float cloud2 = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, uv2, 0).g;
    float cloud3 = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, uv3, 0).b;
    float cloud4 = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, uv4, 0).a;
    float4 skyTexture = float4(cloud1, cloud2, cloud3, cloud4);
    float3 skyTextureRGBWithWeight = float3(skyTexture.x * _CloudChannelWeight.x,  skyTexture.y * _CloudChannelWeight.y, skyTexture.z * _CloudChannelWeight.z);
    float skyTextureValueMax = max(max(skyTextureRGBWithWeight.x, skyTextureRGBWithWeight.y), skyTextureRGBWithWeight.z);
    // ConservativeDensity
    float conservativeDensity = lerp(skyTextureValueMax, max(skyTextureValueMax, skyTexture.w), _Stormy);
    // Weight By 2D Cloud Texture -> select the max value
    float skyTextureWeightForVolumeNoise = lerp(skyTextureValueMax, skyTexture.w, _Stormy);
    // Profile
    
    float2 profileUV1 = float2(normalizedHeight, cloud1);
    float2 profileUV2 = float2(normalizedHeight, cloud2);
    float2 profileUV3 = float2(normalizedHeight, cloud3);
    float2 profileUV4 = float2(normalizedHeight, cloud4);

    float profile1 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV1, 0).r;
    float profile2 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV2, 0).g;
    float profile3 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV3, 0).b;
    float profile4 = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, profileUV4, 0).a;
    float4 profileTexture = float4(profile1, profile2, profile3, profile4);
    float3 profileRGBWithWeight = float3(profileTexture.x * _CloudChannelWeight.x, profileTexture.y * _CloudChannelWeight.y, profileTexture.z * _CloudChannelWeight.z);
    float profileAWithWeight = profileTexture.w * _CloudChannelWeight.w;
    float profileTextureValueMax = max(max(profileRGBWithWeight.x, profileRGBWithWeight.y), profileRGBWithWeight.z);
    float profileValue = lerp(profileTextureValueMax, profileAWithWeight, _Stormy);
    // Blend Profiles + Volume Noise -> select the max value
    float profilesBlendValueForVolumeNoise = profileValue - 0.5; // [-0.5, +0.5]
    // ----------------------------------------- Wind --------------------------------------- //

    // cloudWind = (windvector, _Time.y / (_CloudTextureSize / _CloudTextureScaleKm * 1000.0))
    float4 cloudWind = GetCloudWind();
    float3 wind = float3(cloudWind.x * cloudWind.w, cloudWind.y * cloudWind.w, cloudWind.z * cloudWind.w);
    // -------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise2(Distortion) -------------------------------------------- //
    float3 noise2WindOffset = wind * _Noise2Speed;
    float3 noise2UVW = float3(skyTextureScale.x * _Noise2Scale.x, skyTextureScale.y * _Noise2Scale.y, skyTextureScale.z * _Noise2Scale.z);
    noise2UVW += noise2WindOffset; 
    float noise2 = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise2UVW, 0).r; // Perlin-Worley
    noise2 -= _Noise2Bias;
    noise2 *= lerp(_Noise2Strength, _Noise2Strength * 3.0, _Stormy);

    float3 distortUVW = float3( (normalizedHeight * (1 - 0.05) + 0.05), 
                                (abs((normalizedHeight * (1 - 0.05) + 0.05) - 0.5) * 2.0) * (abs((normalizedHeight * (1 - 0.05) + 0.05) - 0.5) * 2.0), 
                                (normalizedHeight * (1 - 0.05) + 0.05));
    // For Add to Noise1UVW
    distortUVW *= noise2;
    // ---------------------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise1 -------------------------------------------- //
    float3 noise1WindOffset = wind * _Noise1Speed;
    float3 noise1UVW = float3(skyTextureScale.x * _Noise1Scale.x, skyTextureScale.y * _Noise1Scale.y, skyTextureScale.z * _Noise1Scale.z);
    noise1UVW += noise1WindOffset;
    // Add DistortUVW to Noise1UVW
    noise1UVW += distortUVW;
    float noise1 = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise1UVW, 0).g; // Worley
    noise1 -= _Noise1Bias;
    noise1 += globalCoverageControl;
    // For Combine Noise3 MultChannel
    noise1 *= _Noise1Strength;
    // ---------------------------------------------------------------------------------------- //

    // ------------------------------------ Noise3 -------------------------------------------- //
    float3 noise3WindOffset = wind * _Noise3Speed;
    float3 noise3UVW = float3(skyTextureScale.x * _Noise3Scale.x, skyTextureScale.y * _Noise3Scale.y, skyTextureScale.z * _Noise3Scale.z);
    noise3UVW += noise3WindOffset;
    float3 noise3Tex = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, noise3UVW, 0).rgb;// rgb Perlin-Worley | Worley1 | Worley2

    // Todo: MultChannel Mask
    //float noise3Weight = dot(noise3Tex.rgb, _MultChannel.rgb); // r
    float noise3Weight = noise3Tex.r;
    noise3Weight = lerp(noise3Weight, noise3Tex.g, _Stormy); // g
    // For Combine Noise3 MultChannel
    noise3Weight *= _MultStrength;
    // For Add Noise3
    float noise3Add = noise3Tex.b - _Noise3Bias; // b
    noise3Add += globalCoverageControl;
    noise3Add *= _Noise3Strength;

    // ---------------------------------------------------------------------------------------- //
    // --------------------------------------- Additive Mask -------------------------------------------- //
    // Add additive mask
    float2 additiveMaskUV = float2(skyTextureScale.x + skyPlacement.x, skyTextureScale.z + skyPlacement.z);
    float3 maskTex = SAMPLE_TEXTURE2D_LOD(_AdditiveMaskTexture, s_linear_repeat_sampler, additiveMaskUV, 0).rgb;
    float3 maskTexWithAMPCWeight = float3(  maskTex.x * _AdditiveMaskPerChannelWeight.x, 
                                            maskTex.y * _AdditiveMaskPerChannelWeight.y, 
                                            maskTex.z * _AdditiveMaskPerChannelWeight.z);
    float3 maskTexWithCPPCWeight = float3(  maskTexWithAMPCWeight.x * _CloudChannelWeight.x, 
                                            maskTexWithAMPCWeight.y * _CloudChannelWeight.y, 
                                            maskTexWithAMPCWeight.z * _CloudChannelWeight.z);
    float maskAdd = max(max(maskTexWithCPPCWeight.x, maskTexWithCPPCWeight.y), maskTexWithCPPCWeight.z) * (_AdditiveMaskContribOffset + _AdditiveMaskContribution) * 0.01;

    // ---------------------------------------------------------------------------------------- //
    // --------------------------------------- Output -------------------------------------------- //
    // 1 Combine Noise3 MultChannel
    noise1 *= noise3Weight;
    // 2 Add Noise3
    noise1 += noise3Add;
    // 3 Blend Profiles + Volume Noise
    noise1 += profilesBlendValueForVolumeNoise;
    // 4 Weight By 2D Cloud Texture
    noise1 *= skyTextureWeightForVolumeNoise;
    // 5 Add additive mask
    noise1 += maskAdd;
    // 6 Global Density
    noise1 *= globalDensity;
    // 7 Fade Near Camera Weight
    float3 camPosition = _WorldSpaceCameraPos.xyz;
    float fncWeight = distance(camPosition, positionWS);
    float weight = saturate((fncWeight - _FadeInStart) / (_FadeInStart + _FadeInDistance));
    noise1 *= weight;
    /*
    float3 camPosition = _WorldSpaceCameraPos.xyz;
    float fncWeight = distance(camPosition, positionWS);
    fncWeight *= 0.00002;
    fncWeight = saturate(fncWeight);
    noise1 *= fncWeight;*/
    // 8 Prevent Shadowing from Above Clouds
    /*
    float preventSFAC;
    if (normalizedHeight > 0.5)
    {
        preventSFAC = 0.0;
    } 
    else if (normalizedHeight == 0.5)
    {
        preventSFAC = 1.0;
    } 
    else
    {
        preventSFAC = 0.0;
    }
    noise1 *= preventSFAC;*/

    // 9 Saturate | density * sigmaT
    return saturate(noise1);

}

// ----------------------------------------- CloudDensityField --------------------------------------------------// 

float CalBaseNoiseFBM(float4 noise)
{
    float worleyFBM = noise.g * 0.625 + noise.b * 0.25 + noise.a * 0.125;
    return Remap(noise.r, 1.0 - worleyFBM, 1.0, 0.0, 1.0);
}

float CalDetailNoiseFBM(float3 noise)
{
    float worleyFBM = noise.r * 0.625 + noise.g * 0.25 + noise.b * 0.125;
    return worleyFBM;
}


float ErosionMipOffset(float distanceToCamera)
{
    return saturate((distanceToCamera - _FadeInStart) / (_FadeInStart + _FadeInDistance));
}


float3 AnimateCloudMapPosition(float3 positionWS)
{
    return positionWS + float3(_WindDirection.x, 0.0, _WindDirection.y) * _LargeWindSpeed * _Time.y;
}

void GetCloudCoverageData(float3 positionWS, out CloudCoverageData data)
{
    ZERO_INITIALIZE(CloudCoverageData, data);
    float2 uv = AnimateCloudMapPosition(positionWS).xz * METER_TO_KILOMETER * _CloudMapTiling.xy  + _CloudMapTiling.zw ;
    
    float3 cloudMapData = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, uv, 0.0).rgb;
    float3 cloudType = SAMPLE_TEXTURE2D_LOD(_ClouTypeTexture, s_linear_repeat_sampler, uv, 0.0).g;
    float4 cloudBrushMapDataAdd = SAMPLE_TEXTURE2D_LOD(_CloudBrushMapTextureAdd, s_linear_repeat_sampler, uv, 0.0).rgba;
    float4 cloudBrushMapTextureSubtract = SAMPLE_TEXTURE2D_LOD(_CloudBrushMapTextureSubtract, s_linear_repeat_sampler, uv, 0.0).rgba;
    data.coverage = float2(cloudMapData.r + cloudBrushMapDataAdd.r - cloudBrushMapTextureSubtract.r, (cloudMapData.r + cloudBrushMapDataAdd.r - cloudBrushMapTextureSubtract.r )  * (cloudMapData.r + cloudBrushMapDataAdd.r - cloudBrushMapTextureSubtract.r ));
    data.coverage = float2(cloudMapData.r , (cloudMapData.r)  * (cloudMapData.r));
    data.coverage = float2(0.9 , 0.81);
    data.cloudType = cloudMapData.y;
    data.rainClouds = 1;
    data.maxCloudHeight = 1.0;
}

void GetCloudLutData(float cloudType, float normalizedHeight, out CloudLutData data) 
{
    ZERO_INITIALIZE(CloudLutData, data);

    float2 uv = float2(cloudType, normalizedHeight);

    float3 densityAOErosion = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler, uv, CLOUD_LUT_MIP_OFFSET).rgb;

    data.density = densityAOErosion.r;
    data.ambientOcclusion = densityAOErosion.g;
    data.erosion = densityAOErosion.b;
}


float3 AnimateShapeNoisePosition(float3 positionWS)
{
    return positionWS + float3(_WindDirection.x, 0.0, _WindDirection.y) * _MediumWindSpeed * _Time.y + float3(0.0, _VerticalShapeWindDisplacement, 0.0);
}

float GetBaseShapeNoise(float3 positionWS, float normalizedHeight, float noiseMipOffset)
{
    // baseUVW
    float3 pos = AnimateShapeNoisePosition(positionWS);
    // add heightBasedWindOffset
    pos += normalizedHeight * float3(_WindDirection.x, 0.0, _WindDirection.y) * _AltitudeDistortionFirstLayer;
    pos *= METER_TO_KILOMETER;
    
    float3 uvw = pos * _BaseShapeNoiseTiling.xyz + float3(_ShapeNoiseOffset.x, _VerticalShapeNoiseOffset, _ShapeNoiseOffset.y);
   
    float4 perlinWorley = SAMPLE_TEXTURE3D_LOD(_PerlinWorley128RGBA, s_trilinear_repeat_sampler, uvw, noiseMipOffset).rgba;

    float lowFrequencyNoise = CalBaseNoiseFBM(perlinWorley);

    return lowFrequencyNoise;
}


float3 AnimateDetailNoisePosition(float3 positionWS)
{
    return positionWS + float3(_WindDirection.x, 0.0, _WindDirection.y) * _MediumWindSpeed * _Time.y + float3(0.0, _VerticalErosionWindDisplacement, 0.0);
}

float GetDetailNoise(float3 positionWS, float normalizedHeight, float erosionMipOffset)
{
    // baseUVW
    float3 pos = AnimateDetailNoisePosition(positionWS);
    // add heightBasedWindOffset
    pos += normalizedHeight * float3(_WindDirection.x, 0.0, _WindDirection.y) * _AltitudeDistortionFirstLayer;
    pos *= METER_TO_KILOMETER;

    float3 uvw = pos * _DetailNoiseTiling.xyz  + float3(_DetailNoiseOffset.x, _VerticlDetailNoiseOffset, _DetailNoiseOffset.y);

    float3 worley = SAMPLE_TEXTURE3D_LOD(_Worley32RGBA, s_trilinear_repeat_sampler, uvw, erosionMipOffset).rgb;

    float highFrequenceNoise = CalDetailNoiseFBM(worley);

    return highFrequenceNoise;
}

void EvaluateCloudPropertiesUE(float3 positionWS, out CloudProperties properties)
{
    ZERO_INITIALIZE(CloudProperties, properties);

    properties.ambientOcclusion = 1.0;

    float3 positionPS = positionWS + float3(0, _EarthRadius, 0);

    if (!PointInsideCloudVolume(positionPS) || positionPS.y < 0.0f)
    {
        return;
    }

    properties.normalizedHeight = EvaluateNormalizedHeightInCloudArea(positionPS);

    properties.sigmaT = 1.0;

    properties.cloudDensity = GetCloudExtictionCofUE(positionWS, properties.normalizedHeight);
}


void EvaluateCloudPropertiesUETest(float3 positionWS, out CloudProperties properties)
{
    ZERO_INITIALIZE(CloudProperties, properties);

    properties.ambientOcclusion = 1.0;

    float3 positionPS = positionWS + float3(0, _EarthRadius, 0);

    if (!PointInsideCloudVolume(positionPS) || positionPS.y < 0.0f)
    {
        return;
    }

    properties.normalizedHeight = EvaluateNormalizedHeightInCloudArea(positionPS);

    properties.sigmaT = 1;

    properties.cloudDensity = GetCloudExtictionCofUETest(positionWS, properties.normalizedHeight);

    if (properties.cloudDensity <= CLOUD_DENSITY_TRESHOLD)
    {
        properties.cloudDensity = 0.0;
        return;
    }
}

void EvaluateCloudProperties(float3 positionWS, float noiseMipOffset, float erosionMipOffset, bool cheapVersion, bool lightSampling, 
                            out CloudProperties properties)
{
    // Convert to planet space
    float3 positionPS = positionWS + float3(0, _EarthRadius, 0);

    // Initliaze all the values to 0 in case
    ZERO_INITIALIZE(CloudProperties, properties);

    // By default the ambient occlusion is 1.0
    properties.ambientOcclusion = 1.0;

    // If the next sampling point is not inside the coud volume the density
    if (!PointInsideCloudVolume(positionPS) || positionPS.y < 0.0f)
        return;

    // Compute the normalized position for the three channels
    //float3 normalizedPos = positionPS / _NormalizationFactor;

    // Evaluate the normalized height of the position within the cloud volume
    properties.normalizedHeight = EvaluateNormalizedHeightInCloudArea(positionPS);


    //**********Firtst layer*********//
    // Evaluate the generic sampling coordinates
    float3 baseNoiseSamplingCoordinatesFirstLayer = float3(AnimateShapeNoisePosition(positionPS).xzy / NOISE_TEXTURE_NORMALIZATION_FACTOR) * _ShapeScaleFirstLayer - float3(_ShapeNoiseOffset.x, _ShapeNoiseOffset.y, _VerticalShapeNoiseOffset);

    // Evaluate the coordinates at which the noise will be sampled and apply wind displacement
    baseNoiseSamplingCoordinatesFirstLayer += properties.normalizedHeight * float3(_WindDirection.x, _WindDirection.y, 0.0f) * _AltitudeDistortionFirstLayer;
 
    // Read the low frequency Perlin-Worley and Worley noises
    float lowFrequencyNoiseFirstLayer = SAMPLE_TEXTURE3D_LOD(_Worley128RGBA, s_trilinear_repeat_sampler, baseNoiseSamplingCoordinatesFirstLayer.xyz, noiseMipOffset);
    
    //**********Firtst layer*********//


    //**********Second layer*********//
    float3 baseNoiseSamplingCoordinatesSecondLayer = float3(AnimateShapeNoisePosition(positionPS).xzy / NOISE_TEXTURE_NORMALIZATION_FACTOR) * _ShapeScaleSecondLayer - float3(_ShapeNoiseOffset.x, _ShapeNoiseOffset.y, _VerticalShapeNoiseOffset);

    // Evaluate the coordinates at which the noise will be sampled and apply wind displacement
    baseNoiseSamplingCoordinatesSecondLayer += properties.normalizedHeight * float3(_WindDirection.x, _WindDirection.y, 0.0f) * _AltitudeDistortionSecondLayer;
 
    // Read the low frequency Perlin-Worley and Worley noises
    float lowFrequencyNoiseSecondLayer =  SAMPLE_TEXTURE3D_LOD(_Worley128RGBA, s_trilinear_repeat_sampler, baseNoiseSamplingCoordinatesSecondLayer.xyz, noiseMipOffset);
    //**********Second layer*********//

    

    
    // Initiliaze the erosion and shape factors (that will be overriden)
    //**********Firtst layer*********//
    float shapeFactorFirstLayer = lerp(0.1, 1.0, _ShapeFirstLayerFactor);
    float erosionFactorFirstLayer = _ErosionFactorFirstLayer;
    //**********Firtst layer*********//

    //**********Second layer*********//
    float shapeFactorSecondLayer = lerp(0.1, 1.0, _ShapeSecondLayerFactor);
    float erosionFactorSecondLayer= _ErosionFactorSecondLayer;
    //**********Second layer*********//

    // Evaluate the cloud coverage data for this position
    CloudCoverageData cloudCoverageData;
    GetCloudCoverageData(positionPS, cloudCoverageData);
    
    CloudCoverageData cloudCoverageData1;
    GetCloudCoverageData(positionPS, cloudCoverageData1);

    // If this region of space has no cloud coverage, exit right away
    if (cloudCoverageData.coverage.x <= CLOUD_DENSITY_TRESHOLD || cloudCoverageData.maxCloudHeight < properties.normalizedHeight)
        return;
    if (cloudCoverageData1.coverage.x <= CLOUD_DENSITY_TRESHOLD || cloudCoverageData1.maxCloudHeight < properties.normalizedHeight)
        return;
    
   
    float heightgradient = smoothstep(_HeightGradientMin,_HeightGradientMax,properties.normalizedHeight);
    
    //densityErosionAO = densityErosionAOCumulus;
    float3 densityErosionAOFirstLayer = SAMPLE_TEXTURE2D_LOD(_CumulusLutPresetMap, s_linear_clamp_sampler, float2(0, properties.normalizedHeight), CLOUD_LUT_MIP_OFFSET).rgb;
    float3 densityErosionAOSecondLayer = SAMPLE_TEXTURE2D_LOD(_AltoStratusLutPresetMap, s_linear_clamp_sampler, float2(0, properties.normalizedHeight), CLOUD_LUT_MIP_OFFSET).rgb;
    
    // Adjust the shape and erosion factor based on the LUT and the coverage
    shapeFactorFirstLayer = shapeFactorFirstLayer ;
    erosionFactorFirstLayer = erosionFactorFirstLayer * densityErosionAOFirstLayer.y;

    shapeFactorSecondLayer = shapeFactorSecondLayer ;
    erosionFactorSecondLayer = erosionFactorSecondLayer * densityErosionAOSecondLayer.y;
    

    // Combine with the low frequency noise, we want less shaping for large clouds
    lowFrequencyNoiseFirstLayer = lerp(1.0, lowFrequencyNoiseFirstLayer, shapeFactorFirstLayer);
    lowFrequencyNoiseSecondLayer = lerp(1.0, lowFrequencyNoiseSecondLayer, shapeFactorSecondLayer);
    
    float base_cloudFristLayer = 1.0 - densityErosionAOFirstLayer.x * cloudCoverageData.coverage.x * (1.0 - shapeFactorFirstLayer);
    base_cloudFristLayer = saturate(Remap(lowFrequencyNoiseFirstLayer, base_cloudFristLayer, 1.0, 0.0, 1.0)) * cloudCoverageData.coverage.y;
    
    float base_cloudSecondLayer = 1.0 - densityErosionAOSecondLayer.x * cloudCoverageData1.coverage.x * (1.0 - shapeFactorSecondLayer);
    base_cloudSecondLayer = saturate(Remap(lowFrequencyNoiseSecondLayer, base_cloudSecondLayer, 1.0, 0.0, 1.0)) * cloudCoverageData1.coverage.y;
    
    // Weight the ambient occlusion's contribution
    properties.ambientOcclusion = densityErosionAOFirstLayer.z;

    // Change the sigma based on the rain cloud data
    properties.sigmaT = lerp(0.04, 0.12, 0.5);
    //properties.sigmaT = 0.04;
    
    // The ambient occlusion value that is baked is less relevant if there is shaping or erosion, small hack to compensate that
    float ambientOcclusionBlend = saturate(1.0 - max(erosionFactorFirstLayer, shapeFactorFirstLayer) * 0.5);
    properties.ambientOcclusion = lerp(1.0, properties.ambientOcclusion, ambientOcclusionBlend);

    //Apply the erosion for nifer details
    if (!cheapVersion)
    {
        float3 fineNoiseSamplingCoordinates = AnimateDetailNoisePosition(positionPS) / NOISE_TEXTURE_NORMALIZATION_FACTOR * _ErosionScaleFirstLayer ;
        
        float4 packingNoise       =  SAMPLE_TEXTURE3D_LOD(_ErosionNoise, s_linear_repeat_sampler, fineNoiseSamplingCoordinates, CLOUD_DETAIL_MIP_OFFSET ).rgba;
        float  billowy_Noise      =  lerp(packingNoise.b * _PackingNoiseChannelBWeight, packingNoise.a * _PackingNoiseChannelAWeight, billowy_type_gradient);
        float  wispy_noise        =  lerp(packingNoise.r *_PackingNoiseChannelRWeight, packingNoise.g * _PackingNoiseChannelGWeight, wispy_noise_gradient);
        float  noise_composite    =  lerp(wispy_noise, billowy_Noise, densityErosionAOFirstLayer.z);// try to use erosion factor control
        float  hhf_noise          =  saturate(lerp( 1 -pow(abs(abs(packingNoise.g * 2.0 - 1.0) * 2.0 - 1.0), 4.0), pow(abs(abs(packingNoise.a * 2.0 - 1.0) * 2.0 - 1.0), 2.0),_HHFNoiseType));
        
        noise_composite = lerp(noise_composite,hhf_noise , erosionMipOffset);
        
        // Compute the weight of the low frequency noise
        float highFrequencyNoise = lerp(0.0, noise_composite, erosionFactorFirstLayer * 0.75f * cloudCoverageData.coverage.x * _ErosionFactorCompensationFirstLayer);
        
        base_cloudFristLayer = Remap(base_cloudFristLayer, highFrequencyNoise, 1.0, 0.0, 1.0);
        //properties.ambientOcclusion = saturate(properties.ambientOcclusion - sqrt(highFrequencyNoise * _ErosionOcclusion));
        //properties.ambientOcclusion = 1;

        float3 fineNoiseSamplingCoordinates1 = AnimateDetailNoisePosition(positionPS) / NOISE_TEXTURE_NORMALIZATION_FACTOR * _ErosionScaleSecondLayer ;
        
        float4 packingNoise1       =  SAMPLE_TEXTURE3D_LOD(_ErosionNoise, s_linear_repeat_sampler, fineNoiseSamplingCoordinates1, CLOUD_DETAIL_MIP_OFFSET ).rgba;
        float  billowy_Noise1      =  lerp(packingNoise1.b * _PackingNoiseChannelBWeight, packingNoise1.a * _PackingNoiseChannelAWeight, billowy_type_gradient);
        float  wispy_noise1        =  lerp(packingNoise1.r * _PackingNoiseChannelRWeight, packingNoise1.g * _PackingNoiseChannelGWeight, wispy_noise_gradient);
        float  noise_composite1    =  lerp(wispy_noise1, billowy_Noise1, densityErosionAOSecondLayer.z);// try to use erosion factor control
        float  hhf_noise1          =  saturate(lerp(1.0 - pow(abs(abs(packingNoise1.g * 2.0 - 1.0) * 2.0 - 1.0), 4.0), pow(abs(abs(packingNoise1.a * 2.0 - 1.0) * 2.0 - 1.0), 2.0), _HHFNoiseType));

        noise_composite1           =  lerp(hhf_noise1, noise_composite1, erosionMipOffset);
        // Compute the weight of the low frequency noise
        
        float highFrequencyNoise1 = lerp(0.0, noise_composite1, erosionFactorSecondLayer * 0.75f * cloudCoverageData1.coverage.x * _ErosionFactorCompensationSecondLayer);
        
        base_cloudSecondLayer = Remap(base_cloudSecondLayer, highFrequencyNoise1, 1.0, 0.0, 1.0) ;
    }
    
   
    properties.ambientOcclusion = 1;
    // Given that we are not sampling the erosion texture, we compensate by substracting an erosion value
    if (lightSampling)
        base_cloudFristLayer -= erosionFactorFirstLayer * 0.1;

    if (lightSampling)
        base_cloudSecondLayer -= erosionFactorSecondLayer * 0.1;
    
    // Make sure we do not send any negative values
    base_cloudFristLayer = max(0, base_cloudFristLayer);
    base_cloudSecondLayer = max(0, base_cloudSecondLayer);
    // Attenuate everything by the density multiplier
    properties.cloudDensity = (pow(base_cloudFristLayer,max(0,_CloudFirstLayerdDensityPow)) * _CloudDensityFirstLayer + pow(base_cloudSecondLayer,max(0,_CloudSecondLayerdDensityPow)) * _CloudDensitySecondLayer) * heightgradient;
}   


// --------------------------------------- Lighting --------------------------------------------------- //
float IsotropicPhase()
{
	return 1.0f / (4.0f * PI);
}

float HenyeyGreensteinPhase(float cosAngle, float g)
{
    float g2 = g * g;
    return (1.0 / (4.0 * PI)) * (1.0 - g2) / PositivePow(1.0 + g2 - 2.0 * g * cosAngle, 1.5);
}

float DualHGPhaseMax(in float PhaseCosTheta, in float PhaseG, in float Silver_intensity, in float Silver_spread)
{
    PhaseG = clamp(PhaseG, -0.999f, 0.999f);
    return max(HenyeyGreensteinPhase(PhaseCosTheta, PhaseG), Silver_intensity * HenyeyGreensteinPhase(PhaseCosTheta, 0.99 - Silver_spread));
}

float DualHGPhase(in float PhaseCosTheta, in float PhaseG, in float PhaseG2, in float PhaseBlend)
{
	PhaseG = clamp(PhaseG, -0.999f, 0.999f);
	PhaseG2 = clamp(PhaseG2, -0.999f, 0.999f);
	PhaseBlend = clamp(PhaseBlend, 0.0f, 1.0f);
	float MiePhaseValueLight0 = HenyeyGreensteinPhase(PhaseCosTheta, PhaseG);
	float MiePhaseValueLight1 = HenyeyGreensteinPhase(PhaseCosTheta, PhaseG2);
	const float Phase = MiePhaseValueLight0 + PhaseBlend * (MiePhaseValueLight1 - MiePhaseValueLight0);
	return Phase;
}

// MutilScattering
// L = L0 + ... + Li where i = 0,..., MsCount-1
// Li = sigmaS[ms] * L(wi) * phase(wi, wo, g[ms]) * TransmittanceToLight * powderEffect
// sigmaS[ms] = sigmaS[0] * pow(MsSFactor, ms)
// sigmaT[ms] = sigmaT[0] * pow(MsEFactor, ms)
// g[ms] = g[0] * pow(EccenticityFactor, ms)
// Li = sigmaS[0] * MsScatterFactor^i * Light(wi) * phase(wi, wo, MsPhaseFactor^i * g[0]) * e^(-MsExtFactor^i * ExtAcc[0] * StepSize)     

ParticipatingMediaPhaseContext SetupParticipatingMediaPhaseContextTest(float cosAngle, float PhaseG0, float PhaseG1, float PhaseBlendWeight, float MsPhaseFactor)
{
    // Multiple scattering. See slide 41 of "Physically Based and Unified Volumetric Rendering in Frostbite"
    ParticipatingMediaPhaseContext PMPC;

    PMPC.Phase0[0] = DualHGPhase(cosAngle, PhaseG0, PhaseG1, PhaseBlendWeight);

    UNITY_UNROLL
    for (int ms = 1; ms < MSCOUNT; ++ms)
    {
        PMPC.Phase0[ms] = DualHGPhase(cosAngle, PhaseG0 * MsPhaseFactor, PhaseG1 * MsPhaseFactor, PhaseBlendWeight);
        MsPhaseFactor *= MsPhaseFactor; // pow(MsPhaseFactor, ms)
    }

    return PMPC;
}

ParticipatingMediaPhaseContext SetupParticipatingMediaPhaseContext(float BasePhase0, float BasePhase1, float MsPhaseFactor)
{
    // Refered to UE
	ParticipatingMediaPhaseContext PMPC;
    
	PMPC.Phase0[0] = BasePhase0;

	for (int ms = 1; ms < MSCOUNT; ++ms)
	{
		PMPC.Phase0[ms] = lerp(IsotropicPhase(), PMPC.Phase0[0], MsPhaseFactor);
		MsPhaseFactor *= MsPhaseFactor;
	}

	return PMPC;
}

ParticipatingMediaContext SetupParticipatingMediaContext(float3 BaseAlbedo, float3 BaseExtinctionCoefficients, 
        float MsSFactor, float MsEFactor, float3 InitialTransmittanceToLight0)
{
    // sigmaS[ms] = sigmaS[0] * pow(MsSFactor, ms)
    // sigmaT[ms] = sigmaT[0] * pow(MsEFactor, ms)
    ParticipatingMediaContext PMC;
    // Albedo = sigma_S / sigma_T
    const float3 ScatteringCoefficients = BaseAlbedo * BaseExtinctionCoefficients;
	PMC.ScatteringCoefficients[0] = ScatteringCoefficients; 
	PMC.ExtinctionCoefficients[0] = BaseExtinctionCoefficients;
	PMC.TransmittanceToLight0[0]  = InitialTransmittanceToLight0;

    UNITY_UNROLL
	for (int ms = 1; ms < MSCOUNT; ++ms)
	{
        //PMC.ScatteringCoefficients[ms] = PMC.ScatteringCoefficients[0] * PositivePow(MsSFactor, ms);
        //PMC.ExtinctionCoefficients[ms] = PMC.ExtinctionCoefficients[0] * PositivePow(MsEFactor, ms);

		PMC.ScatteringCoefficients[ms] = PMC.ScatteringCoefficients[ms - 1] * MsSFactor;
		PMC.ExtinctionCoefficients[ms] = PMC.ExtinctionCoefficients[ms - 1] * MsEFactor;
		MsSFactor *= MsSFactor; // PositivePow(MsSFactor, ms);
		MsEFactor *= MsEFactor;

		PMC.TransmittanceToLight0[ms] = InitialTransmittanceToLight0;
	}

	return PMC;
}

float2 RayIntersectSphere(float3 RayOrigin, float3 RayDirection, float4 Sphere)
{
	float3 LocalPosition = RayOrigin - Sphere.xyz;
	float LocalPositionSqr = dot(LocalPosition, LocalPosition);

	float3 QuadraticCoef;
	QuadraticCoef.x = dot(RayDirection, RayDirection);
	QuadraticCoef.y = 2 * dot(RayDirection, LocalPosition);
	QuadraticCoef.z = LocalPositionSqr - Sphere.w * Sphere.w;

	float Discriminant = QuadraticCoef.y * QuadraticCoef.y - 4 * QuadraticCoef.x * QuadraticCoef.z;

	float2 Intersections = -1;

	// Only continue if the ray intersects the sphere
	if (Discriminant >= 0)
	{
		float SqrtDiscriminant = sqrt(Discriminant);
		Intersections = (-QuadraticCoef.y + float2(-1, 1) * SqrtDiscriminant) / (2 * QuadraticCoef.x);
	}

	return Intersections;
}

void getTransmittanceLutUvs(
	in float viewHeight, in float viewZenithCosAngle, in float BottomRadius, in float TopRadius,
	out float2 UV)
{
	float H = sqrt(max(0.0f, TopRadius * TopRadius - BottomRadius * BottomRadius));
	float Rho = sqrt(max(0.0f, viewHeight * viewHeight - BottomRadius * BottomRadius));

	float Discriminant = viewHeight * viewHeight * (viewZenithCosAngle * viewZenithCosAngle - 1.0f) + TopRadius * TopRadius;
	float D = max(0.0f, (-viewHeight * viewZenithCosAngle + sqrt(Discriminant))); // Distance to atmosphere boundary

	float Dmin = TopRadius - viewHeight;
	float Dmax = Rho + H;
	float Xmu = (D - Dmin) / (Dmax - Dmin);
	float Xr = Rho / H;

	UV = float2(Xmu, Xr);
	//UV = float2(fromUnitToSubUvs(UV.x, TRANSMITTANCE_TEXTURE_WIDTH), fromUnitToSubUvs(UV.y, TRANSMITTANCE_TEXTURE_HEIGHT)); // No real impact so off
}

float3 GetAtmosphereTransmittance(
	float3 PlanetCenterToWorldPosKm, float3 SunDir, float BottomRadius, float TopRadius)
{
	// For each view height entry, transmittance is only stored from zenith to horizon. Earth shadow is not accounted for.
	// It does not contain earth shadow in order to avoid texel linear interpolation artefact when LUT is low resolution.
	// As such, at the most shadowed point of the LUT when close to horizon, pure black with earth shadow is never hit.
	// That is why we analytically compute the virtual planet shadow here.
    // Beneath the horizon, return 0.0;
    const float2 Sol = RayIntersectSphere(PlanetCenterToWorldPosKm, SunDir, float4(float3(0.0f, 0.0f, 0.0f), BottomRadius)); 
    //const float2 Sol = RayIntersectSphere(PlanetCenterToWorldPosKm, SunDir, float4(float3(_WorldSpaceCameraPos.x, -BottomRadius, _WorldSpaceCameraPos.z), BottomRadius)); 
	if (Sol.x > 0.0f || Sol.y > 0.0f)
	{
		return 0.0f;
	}

	const float PHeight = length(PlanetCenterToWorldPosKm);
	const float3 UpVector = PlanetCenterToWorldPosKm / PHeight;
	const float LightZenithCosAngle = dot(SunDir, UpVector);
	float2 TransmittanceLutUv;
	getTransmittanceLutUvs(PHeight, LightZenithCosAngle, BottomRadius, TopRadius, TransmittanceLutUv);
	//const float3 TransmittanceToLight = Texture2DSampleLevel(TransmittanceLutTexture, TransmittanceLutTextureSampler, TransmittanceLutUv, 0.0f).rgb;
    const float3 TransmittanceToLight = SAMPLE_TEXTURE2D_LOD(_TransmittanceLutTexture, s_linear_clamp_sampler, TransmittanceLutUv, 0.0f).rgb;
	return 1;
}

float BeerLambertLawMax(float opticalLength)
{
    return max(exp(-opticalLength), exp(-opticalLength * 0.25) * 0.7);
}

// Horizon zero dawn technique to darken the clouds


// This functions evaluates the sun color attenuation at a given point (if the physicaly based sky is active)
void EvaluateSunColorAttenuation(float3 evaluationPointWS, float3 sunDirection, inout half3 sunColor)
{
    const float3 PlanetCenterToWorldPosKm = (evaluationPointWS + float3(0.0f, _EarthRadius, 0.0f)) * METER_TO_KILOMETER;
    float3 AtmosphereTransmittanceToLight = GetAtmosphereTransmittance(PlanetCenterToWorldPosKm, sunDirection, _SkyAtmosphereBottomRadiusKm, _SkyAtmosphereTopRadiusKm);
    sunColor *= AtmosphereTransmittanceToLight;
}

float3 EvaluateSunColor(EnvironmentLighting envLighting, float relativeRayDistance)
{
    return lerp(envLighting.sunColor0, envLighting.sunColor1, relativeRayDistance);
}

EnvironmentLighting EvaluateEnvironmentLightingAndPMPC(float3 cloudRayDir, float3 entryEvaluationPointWS, float3 exitEvaluationPointWS)
{
    // Sun parameters
    EnvironmentLighting lighting;
    lighting.sunDirection = _SunDirection.xyz;
    lighting.sunColor0 = _SunLightColor.rgb;
    lighting.sunColor1 = lighting.sunColor0;
    lighting.ambientTermTop = SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, half3(0.0, 1.0, 0.0), 5.0).rgb * _AmbientLightingTint;
    lighting.ambientTermBottom = _GlossyEnvironmentColor.xyz;
    
    // evaluate the attenuation at both points (entrance and exit of the cloud layer)
    EvaluateSunColorAttenuation(entryEvaluationPointWS, lighting.sunDirection, lighting.sunColor0);
    EvaluateSunColorAttenuation(exitEvaluationPointWS, lighting.sunDirection, lighting.sunColor1);
     
    // Evaluate cos of the theta angle between the view and light vectors
    lighting.cosAngle = -abs(dot(cloudRayDir, lighting.sunDirection)); // dot(backViewRay, sunForward) == dot(-cloudRayDir, -sunDirection)

    // Evaluate the phase function for each of the octaves
    lighting.cloudPMPC = SetupParticipatingMediaPhaseContextTest(lighting.cosAngle, _PhaseG0, _PhaseG1, _PhaseBlendWeight, _MsPhaseFactor) ;

    return lighting;
}


float Depth_Probality(float cloudDensity, float normalizedHeight)
{
    return 0.05 + PositivePow(cloudDensity, Remap(normalizedHeight, 0.3, 0.85, 0.5, 2.0));
}

float Vertical_Probality(float normalizedHeight)
{
    return PositivePow(Remap(normalizedHeight, 0.07, 0.014, 0.1, 1.0), 0.8);
}

// Function that intersects a ray in absolute world space, the ray is guaranteed to start inside the volume
bool GetCloudVolumeIntersection_Light(float3 originWS, float3 dir, out float totalDistance)
{
    // Given that this is a light ray, it will always start from inside the volume and is guaranteed to exit
    float2 intersection;
    RaySphereIntersection(originWS, dir, _CloudLayerBottomAltitude + _CloudLayerThickness + _EarthRadius, intersection);
    bool intersectEarth = RaySphereIntersection(originWS, dir, _EarthRadius);
    totalDistance = intersection.x;
    // If the ray intersects the earth, then the sun is occlued by the earth
    return !intersectEarth;
}

void EvaluateVolumetricShadow(float3 positionWS, float3 sunDirection, inout ParticipatingMediaContext PMC)
{
    // Compute the Ray to the limits of the cloud volume in the direction of the light
    float totalLightDistance = 0.0;
    if (GetCloudVolumeIntersection_Light(positionWS, sunDirection, totalLightDistance))
    {
        // Because of the very limited numebr of light steps and the potential humongous distance to cover, we decide to potnetially cover less and make it more useful
        totalLightDistance = clamp(totalLightDistance, 0, _NumLightSteps * LIGHT_STEP_MAXIMAL_SIZE);
        
        // Apply a small bias to compensate for the imprecision in the ray-sphere intersection at world scale.
        totalLightDistance += 5.0f;
        // Compute the size of the current step
        float intervalSize = totalLightDistance / (float)_NumLightSteps;
        // For Suming the extiction
        float ExtinctionAcc[MSCOUNT];
        int ms;
        for (ms = 0; ms < MSCOUNT; ++ms)
        {
            ExtinctionAcc[ms] = 0.0f;
        }

        // Todo:using transmittanceShadowMap for Raymarching Optimaztion
        for (int j = 0; j < _NumLightSteps; j++)
        {
            // Here we intentionally do not take the right step size for the first step
            // as it helps with darkening the clouds a bit more than they should at low light samples
            float dist = intervalSize * (0.25 + j);

            // Evaluate the current sample point
            float3 currentSamplePointWS = positionWS + sunDirection * dist;

            CloudProperties lightRayCloudProperties;
            
           

            EvaluateCloudProperties(currentSamplePointWS, 0.0, 0.0, false, true, lightRayCloudProperties);
            
            float sampledSigmaT = lightRayCloudProperties.cloudDensity * lightRayCloudProperties.sigmaT;

            // Evaluate ExtinctionCofficients to sum the extiction
            ParticipatingMediaContext ShadowPMC = SetupParticipatingMediaContext(_Albedo, sampledSigmaT, _MsScattFactor, _MsExtinFactor, 1.0f);

            for(ms = 0; ms < MSCOUNT; ++ms)
            {
                ExtinctionAcc[ms] += max(ShadowPMC.ExtinctionCoefficients[ms].x, 1e-6f);
            }
        }

        
        // Compute the VolumetricShadow to Light
        UNITY_UNROLL
        for(ms = 0; ms < MSCOUNT; ++ms)
        {
            //PMC.TransmittanceToLight0[ms] *= exp(-ExtinctionAcc[ms] * intervalSize);
            PMC.TransmittanceToLight0[ms] *= max(exp(-ExtinctionAcc[ms] * intervalSize), exp(-ExtinctionAcc[ms] * intervalSize * 0.25) * 0.7);
        }
    }
}

void EvaluateLuminance(in CloudProperties cloudProperties, in EnvironmentLighting envLighting, in ParticipatingMediaContext PMC, float inscattering_probality, float stepSize, float relativeRayDistance,
         inout VolumetricRayResult volumetricRay)
{
    // L = sum(Li) where i = 0,..., MSCOUNT-1
    // Li = sigmaS[i] * Light(wi) * phase[ms] * TransmittanceToLight[ms] * in_scatteringP;
    float3 Luminance = float3(0.0, 0.0, 0.0);
    for (int ms = MSCOUNT - 1; ms >= 0; --ms)
    {
        float3 ScatteringCoefficients = PMC.ScatteringCoefficients[ms];
        float ExtinctionCoefficients = PMC.ExtinctionCoefficients[ms].x;
        float TransmittanceToLight = PMC.TransmittanceToLight0[ms].x;

        float3 SunColor = EvaluateSunColor(envLighting, relativeRayDistance);
        
        float3 SunLuminance = TransmittanceToLight * inscattering_probality * SunColor * envLighting.cloudPMPC.Phase0[ms] * _SilverIntensity;

        float3 AmbientLuminance = (ms == 0 ? (lerp(envLighting.ambientTermTop * saturate(_AmbientLightingBottomVisibility + cloudProperties.normalizedHeight), 
            envLighting.ambientTermBottom, cloudProperties.normalizedHeight)) : float3(0.0f, 0.0f, 0.0f));

        AmbientLuminance *= cloudProperties.ambientOcclusion;
        AmbientLuminance *= _AmbientLuminanceIntensity;

        float3 ScatteredLuminance = (SunLuminance + AmbientLuminance) * ScatteringCoefficients;

        // Improved scattering integration. See slide 29 of "Physically Based and Unified Volumetric Rendering in Frostbite"
        float SafeExtinctionThreshold = 0.000001f;
        float SafeExtinctionCoefficients = max(SafeExtinctionThreshold, PMC.ExtinctionCoefficients[ms].x);
        //float SafePathSegmentTransmittance = exp(-SafeExtinctionCoefficients * stepSize);
        float SafePathSegmentTransmittance = max(exp(-SafeExtinctionCoefficients * stepSize), exp(-SafeExtinctionCoefficients * stepSize * 0.25) * 0.7);
        float3 LuminanceIntegral = (ScatteredLuminance - ScatteredLuminance * SafePathSegmentTransmittance) / SafeExtinctionCoefficients;
        float3 LuminanceContribution = volumetricRay.transmittanceToView * LuminanceIntegral;
            Luminance += LuminanceContribution;
    
        if (ms == 0)
        {
            volumetricRay.transmittanceToView *= SafePathSegmentTransmittance;
        }
    }

    volumetricRay.inScattering += Luminance;
} 


void EvaluateCloud(CloudProperties cloudProperties, EnvironmentLighting envLighting, float3 currentPositionWS, float stepSize, float relativeRayDistance,
                inout VolumetricRayResult volumetricRay)
{
    // Apply the extinction
    float sampledSigmaT = cloudProperties.cloudDensity * cloudProperties.sigmaT;
    // Powder_Effect
    float inscattering_probality = PowderEffect(cloudProperties.cloudDensity,envLighting.cosAngle,1);
    // Setup MSSigmaS|MSSigmaT
    ParticipatingMediaContext PMC = SetupParticipatingMediaContext(_Albedo, sampledSigmaT, _MsScattFactor, _MsExtinFactor, 1.0f);
    // Evaluate MS VolumetricShadow To Light
    EvaluateVolumetricShadow(currentPositionWS, envLighting.sunDirection, PMC);
    // Evaluate MS Luminance
   EvaluateLuminance(cloudProperties, envLighting, PMC, inscattering_probality, stepSize, relativeRayDistance, volumetricRay);
    
}


VolumetricRayResult TraceVolumetricRay(CloudRay cloudRay)
{
    // Initiliaze the volumetric ray
    VolumetricRayResult volumetricRay;
    volumetricRay.inScattering = 0.0;
    volumetricRay.transmittanceToView = 1.0;
    volumetricRay.meanDistance = _MaxCloudDistance;
    volumetricRay.invalidRay = true;

    // Determine if ray intersects bounding volume, if the ray does not intersect the cloud volume AABB, skip right away
    RayMarchRange rayMarchRange;
    if (GetCloudVolumeIntersection(cloudRay.originWS, cloudRay.direction, cloudRay.insideClouds, cloudRay.toEarthCenterLength, rayMarchRange))
    {
        if (cloudRay.maxRayLength >= rayMarchRange.start) 
        {
            // Initialize the depth for accumulation
            volumetricRay.meanDistance = 0.0;

            // Clamp the travel distance to whatever is closer
            // - Sky Occluder
            // - Volume end
            // - SkyBox end
            float totalDistance = min(rayMarchRange.distance, cloudRay.maxRayLength - rayMarchRange.start);
            
            // Compute the environment lighting that is going to be used for the cloud evaluation
            float3 rayMarchStartPos = cloudRay.originWS + rayMarchRange.start * cloudRay.direction;
            float3 rayMarchEndPos = rayMarchStartPos + totalDistance * cloudRay.direction;
            cloudRay.envLighting = EvaluateEnvironmentLightingAndPMPC(cloudRay.direction, rayMarchStartPos, rayMarchEndPos);

            // Evaluate our integration step
            float stepSize = totalDistance / (float)_NumPrimarySteps;

            // Tracking the number of steps that have been made
            int currentIndex = 0;

            // Normalization value of the depth
            float meanDistanceDivider = 0.0f;

            // Current position for the evaluation
            float3 currentPositionWS = cloudRay.originWS + rayMarchRange.start * cloudRay.direction;

            // Current Distance that has been marched
            float currentDistance = 0;

            // Initialize the values for the optimized ray marching
            bool activeSampling = true;
            int sequentialEmptySamples = 0;

            // Todo: LOD
            while (currentIndex < _NumPrimarySteps && currentDistance < totalDistance)
            {
                
                // Compute the camera-distance based attenuation
                // float densityAttenuationValue = DensityFadeValue(rayMarchRange.start + currentDistance);
                // Compute the mip offset for the erosion texture
                // float erosionMipOffset = ErosionMipOffset(rayMarchRange.start + currentDistance);
                // Compute the camera-distance based attenuation
                // float densityAttenuationValue = DensityFadeValue(rayMarchRange.start + currentDistance);
                // Compute the mip offset for the erosion texture
                // float erosionMipOffset = ErosionMipOffset(rayMarchRange.start + currentDistance);
                
                // Compute the camera-distance based attenuation
                float densityAttenuationValue = DensityFadeValue(rayMarchRange.start + currentDistance);
                // Compute the mip offset for the erosion texture
                float erosionMipOffset =  1-ErosionMipOffset(rayMarchRange.start + currentDistance);
                // LOD_ExpensiveVersion
                if (activeSampling)
                {
                    CloudProperties cloudProperties;

                    
                    //EvaluateCloudProperties(currentPositionWS, 0.0f, 0.0f, false, false, cloudProperties);

                    //EvaluateCloudPropertiesUE(currentPositionWS, cloudProperties);

                    //EvaluateCloudPropertiesUETest(currentPositionWS, cloudProperties);
                    EvaluateCloudProperties(currentPositionWS, 0.0f, erosionMipOffset, false, false, cloudProperties);
                    
                    
                    if (cloudProperties.cloudDensity > CLOUD_DENSITY_TRESHOLD)
                    {
                        // Contribute to the average depth (must be done first in case we end up inside a cloud at the next step)
                        // AverageCloudDepth = sum(Transmittance(x) * Distance(x)) / sum(Transmittance(x))
                        float transmitanceXdensity = volumetricRay.transmittanceToView * cloudProperties.cloudDensity;
                        volumetricRay.meanDistance += (rayMarchRange.start + currentDistance) * transmitanceXdensity;
                        meanDistanceDivider += transmitanceXdensity;

                        // Evaluate the cloud at the position
                        EvaluateCloud(cloudProperties, cloudRay.envLighting, currentPositionWS, stepSize, currentDistance / totalDistance, volumetricRay);
                                                // if most of the energy is absorbed, just leave.
                        if (volumetricRay.transmittanceToView < CLOUD_TRANSMITTANCE_TRESHOLD)
                        {
                            volumetricRay.transmittanceToView = 0.0;
                            break;
                        }

                        // Reset the empty sample counter For Raymarching Optimization
                        sequentialEmptySamples = 0;
                    } 
                    else
                    {
                        // If the density is lower than our tolerance, record emptySample num for Optimization
                        sequentialEmptySamples++;
                    }
                    
                    if (sequentialEmptySamples == EMPTY_STEPS_BEFORE_LARGE_STEPS)
                    {
                        activeSampling = false;
                    }
                    // if currentIndex == 0, add blue noise
                    float relativeStepSize = lerp(cloudRay.integrationNoise * _BlueNoiseIntensity, 1.0, saturate(currentIndex));
                    currentPositionWS += cloudRay.direction * stepSize * relativeStepSize;
                    currentDistance += stepSize * relativeStepSize;
                }
                else
                {
                    CloudProperties cloudProperties;
                    // Todo:LOD_CheapVersion
                    //EvaluateCloudPropertiesUETest(currentPositionWS, cloudProperties);
                    EvaluateCloudProperties(currentPositionWS, 1.0f, 0.0, true, false, cloudProperties);
                    
                    //cloudProperties.cloudDensity *= densityAttenuationValue;
                    
                    // If the density is lower than our tolerance, use a bigger StepSize(2x)
                    if (cloudProperties.cloudDensity < CLOUD_DENSITY_TRESHOLD)
                    {
                        currentPositionWS += cloudRay.direction * stepSize * 2.0f;
                        currentDistance += stepSize * 2.0f;
                    }
                    else
                    {
                        // If the density is higher than our tolerance, back StepSize for caculating lighting
                        currentPositionWS -= cloudRay.direction * stepSize;
                        currentDistance -= stepSize;
                        activeSampling = true;
                        sequentialEmptySamples = 0;
                    }
                }

                currentIndex++;
            }

            // Normalized the depth we computed
            if (volumetricRay.meanDistance == 0.0) // NoCloud
            {
                volumetricRay.invalidRay = true;
            }
            else
            {
                volumetricRay.meanDistance /= meanDistanceDivider;
                volumetricRay.invalidRay = false;
            }

        }
    }
    
    // return the final ray result
    return volumetricRay;
}

// Fonction that takes a world space position and converts it to a depth value
float ConvertCloudDepth(float3 position)
{
    // WS => CS => /w => depth
    // mul(UNITY_MATRIX_VP, worldPos);
    float4 hClip = TransformWorldToHClip(position);
    return hClip.z / hClip.w;
}

float ConvertToDeviceZ(float2 NDCxy, float distance)
{
    float3 worldPos = ComputeWorldSpacePosition(NDCxy, UNITY_RAW_FAR_CLIP_VALUE, UNITY_MATRIX_I_VP);
    float3 worldPosToCamRay = normalize(worldPos - _WorldSpaceCameraPos.xyz);

    float3 PixelWorldPos = _WorldSpaceCameraPos.xyz + distance * worldPosToCamRay;
    return ConvertCloudDepth(PixelWorldPos);
}


void ComputeCloudLightingAndDepth(in uint2 intermediateCoord, 
    out float4 CloudsLighting, out float CloudsDepth)
{
    // Default no cloud case
    CloudsLighting = float4(0.0, 0.0, 0.0, 1.0);
    CloudsDepth = UNITY_RAW_FAR_CLIP_VALUE; 

    CloudRay cloudRay = BuildRay(intermediateCoord);
    VolumetricRayResult result = TraceVolumetricRay(cloudRay);
    
    // Cloud.inscattering/transmittanceToView
    CloudsLighting = float4(result.inScattering, result.transmittanceToView);
    //CloudsLighting = float4(cloudRay.integrationNoise, 0.0, 0.0, 0.0);
    // CloudDepthData
    float minimalDistance = min(result.meanDistance, cloudRay.maxRayLength);

    // If we are processing local clouds, we store the distance information as a depth, otherwise we just store the distance (for the fog).
#if defined(LOCAL_VOLUMETRIC_CLOUDS)
    // Compute the cloud depth
    float cloudMinDistance = clamp(minimalDistance, _ProjectionParams.y, _ProjectionParams.z);
    float cloudMinDepth = result.invalidRay ? cloudRay.depthValue : ConvertCloudDepth(cloudRay.originWS + cloudRay.direction * cloudMinDistance);
    CloudsDepth = cloudMinDepth; 
#else
    // Output the cloud distance
    CloudsDepth = result.invalidRay ? cloudRay.maxRayLength : max(minimalDistance, _ProjectionParams.y); 
#endif

}

#endif // VOLUMETRIC_CLOUD_UTILITIES_PS_H
