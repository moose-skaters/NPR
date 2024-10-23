#ifndef VOLUMERENDERING_H
#define VOLUMERENDERING_H

static const float FLT_EPSILON = 0.001f;
static const float FLT_EPSILON2 = 0.01f;



// Calculate the line integral of the ray from the camera to the receiver position through the fog density function
// The exponential fog density function is d = GlobalDensity * exp(-HeightFalloff * z)
float CalculateLineIntegralShared(float FogHeightFalloff, float RayDirectionYLength, float RayOriginTerms)
{
	float Falloff = max(-127.0f, FogHeightFalloff * RayDirectionYLength);    // if it's lower than -127.0, then exp2() goes crazy in OpenGL's GLSL.
	float LineIntegral = ( 1.0f - exp2(-Falloff) ) / Falloff;
	float LineIntegralTaylor = log(2.0) - ( 0.5 * pow(log(2.0), 2) ) * Falloff;		// Taylor expansion around 0
    
    return RayOriginTerms * (abs(Falloff) > FLT_EPSILON2 ? LineIntegral : LineIntegralTaylor);
}

float3 ComputeInscatteringColor(float3 CameraToReceiver, float CameraToReceiverLength)
{
	half3 Inscattering = _ExponentialFogColorParameter.xyz;

    // Todo: Add Fog Inscattering Texture

    // Todo: Add Atmosphere Effect
    Inscattering += _FogDistantSkyLight.rgb * _FogDistantSkyLight.a;

	return Inscattering;
}

float3 ComputeDirectionalLightInscatteringColor(half3 CameraToReceiverNormalized, float ExponentialHeightLineIntegralShared, float RayLength)
{
    // _FogDirectionalInscatteringColor = (_SunLightColor.rgb * _Tint, _DirectionalInscatteringExponent)
    // _FogInscatteringLightDirection = (_SunDirection.xyz, _FogDirectionalInscatteringStartDistance)

    // Todo: Add Atmosphere Effect

    half3 DirectionalLightInscattering = _FogDirectionalInscatteringColor.xyz * 
                                        pow(saturate(dot(CameraToReceiverNormalized, _FogInscatteringLightDirection.xyz)), _FogDirectionalInscatteringColor.w);
    // Calculate the line integral of the eye ray through the haze, using a special starting distance to limit the inscattering to the distance
    float DirectionalInscatteringStartDistance = _FogInscatteringLightDirection.w;
    float DirExponentialHeightLineIntegral = ExponentialHeightLineIntegralShared * max(RayLength - DirectionalInscatteringStartDistance, 0.0f);
    // Calculate the amount of light that made it through the fog using the transmission equation
    half DirectionalInscatteringFogFactor = saturate(exp2(-DirExponentialHeightLineIntegral));

    return _ExponentialFogParameters3.z * DirectionalLightInscattering * (1.0 - DirectionalInscatteringFogFactor);
}


// _ExponentialFogParameters: 
// [FogDensity * exp2(-FogHeightFalloff * (CameraWorldPosition.z - FogHeight))] in x, [FogHeightFalloff] in y, 
// [MaxWorldObserverHeight] in z, [StartDistance] in w. 

// _ExponentialFogParameters2: 
// [FogDensitySecond * exp2(-FogHeightFalloffSecond * (CameraWorldPosition.z - FogHeightSecond))] in x, [FogHeightFalloffSecond] in y, 
// [FogDensitySecond] in z, [FogHeightSecond] in w 

// _ExponentialFogParameters3: 
// [FogDensity] in x, [FogHeight] in y, whether to use [Cubemap fog color] in z, [FogCutoffDistance] in w. 

// FogInscatteringTextureParameters: 
// [mip distance scale] in x, [bias] in y, [num mips] in z 

// _ExponentialFogColorParameter: 
// [mip distance scale] in x, [bias] in y, [num mips] in z 


// Density = _FogDensity * 2 ^ (-HeightOff * (CamFogStartHeight - FogHeight))
// FogFactor = (1 - 2 ^ (-HeightOff * relativeHeight)) / (HeightOff * relativeHeight)
// Fog = FogDensity * FogFactor * max(RayLength - FogStartDistance, 0)
// Add InscatterFog

// @param WorldPositionRelativeToCamera = WorldPosition - InCameraPosition
half4 GetExponentialHeightFog(float3 WorldPositionRelativeToCamera, float ExcludeDistance)
{
    const half MinFogOpacity = _ExponentialFogColorParameter.w;
    const float MaxWorldObserverHeight = _ExponentialFogParameters.z;
    const float3 WorldObserverOrigin = float3(_WorldSpaceCameraPos.x, min(_WorldSpaceCameraPos.y, MaxWorldObserverHeight), _WorldSpaceCameraPos.z);

    // Calculate CameraToReceiverLength、Dir
    float3 CameraToReceiver = WorldPositionRelativeToCamera;
    CameraToReceiver.y += (_WorldSpaceCameraPos.y - WorldObserverOrigin.y);
    float CameraToReceiverLengthSqr = dot(CameraToReceiver, CameraToReceiver);
    float CameraToReceiverLengthInv = rsqrt(max(CameraToReceiverLengthSqr, 0.00000001f)); // rcp(sqrt(CameraToReceiverLengthSqr))
	
    float CameraToReceiverLength = CameraToReceiverLengthSqr * CameraToReceiverLengthInv;//算出向量长度
    half3 CameraToReceiverNormalized = CameraToReceiver * CameraToReceiverLengthInv;

    // Initialize
    float RayOriginTerms = _ExponentialFogParameters.x; // _FogDensity * exp2(-_FogHeightOff * (CamHeight - _FogHeight))
    float RayLength = CameraToReceiverLength;
    float RayDirectionYLength = CameraToReceiver.y;

    // Factor in StartDistance
    ExcludeDistance = max(ExcludeDistance, _ExponentialFogParameters.w); // Limited by StartDistance
    if (ExcludeDistance > 0) 
    {
        // Calculate FogStartHeight by _FogStartDistance
        float ExcludeIntersectionTime = ExcludeDistance * CameraToReceiverLengthInv;
        float CameraToExclusionIntersectionY = ExcludeIntersectionTime * RayDirectionYLength;
        float ExclusionIntersectionY = WorldObserverOrigin.y + CameraToExclusionIntersectionY;
        float ExclusionIntersectionToReceiverY = CameraToReceiver.y - CameraToExclusionIntersectionY;

        // Calculate fog off of the ray starting from the exclusion distance, instead of starting from the camera
        RayLength = (1.0f - ExcludeIntersectionTime) * CameraToReceiverLength;
        RayDirectionYLength = ExclusionIntersectionToReceiverY;

        // OriginDensity = _FogDensity * 2 ^ (- FogHeightFalloff * (CamToFogStartHeight - FogHeight))
		float Exponent = max(-127.0f, _ExponentialFogParameters.y * (ExclusionIntersectionY - _ExponentialFogParameters3.y));
		RayOriginTerms = _ExponentialFogParameters3.x * exp2(-Exponent);

    }

    // Calculate the "shared" line integral (this term is also used for the directional light inscattering) 
    // by adding the two line integrals together (from two different height falloffs and densities)
    float ExponentialHeightLineIntegralShared = CalculateLineIntegralShared(_ExponentialFogParameters.y, RayDirectionYLength, RayOriginTerms);

    float ExponentialHeightLineIntegral = ExponentialHeightLineIntegralShared * RayLength;

    // Calculate Fog Inscattering
    half3 InscatteringColor = ComputeInscatteringColor(CameraToReceiver, CameraToReceiverLength);

    // Calculate DirectionalLight Inscattering
    half3 DirectionalInscattering = 0;
    // if InscatteringLightDirection.w is negative then it's disabled, otherwise it holds directional inscattering start distance
    if (_FogInscatteringLightDirection.w >= 0)
    {
        DirectionalInscattering = ComputeDirectionalLightInscatteringColor(CameraToReceiverNormalized, ExponentialHeightLineIntegral, RayLength);
    }

    // Calculate the amount of light that made it through the fog using the transmission equation
    half ExpFogFactor = max(saturate(exp2(-ExponentialHeightLineIntegral)), MinFogOpacity);

    if (_ExponentialFogParameters3.w > 0 && CameraToReceiverLength > _ExponentialFogParameters3.w)
    {
        ExpFogFactor = 1;
        DirectionalInscattering = 0;
    }

    // Calculate FogColor
    half3 FogColor = (InscatteringColor) * (1.0 - ExpFogFactor) + DirectionalInscattering;

    return half4(FogColor, ExpFogFactor);
}

half4 CalculateHeightFog(float3 WorldPositionRelativeToCamera)
{
	float ExcludeDistance = 0;

    // Todo:Volumetric fog

    // HeightFog
	half4 FogInscatteringAndOpacity = GetExponentialHeightFog(WorldPositionRelativeToCamera, ExcludeDistance);
	return FogInscatteringAndOpacity;
}


#endif // VOLUMERENDERING_H