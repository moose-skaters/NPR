#ifndef VOLUMETRIC_CLOUD_Lib
#define VOLUMETRIC_CLOUD_Lib

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
  float Remap(float value, float oldMin, float oldMax, float newMin, float newMax)
            {
                return (((value - oldMin) / (oldMax - oldMin)) * (newMax - newMin)) + newMin;
            }
            float Vertical_Probality(float normalizedHeight)
            {
                return PositivePow(Remap(normalizedHeight, 0.07, 0.014, 0.1, 1.0), 0.8);
            }
            float Depth_Probality(float cloudDensity, float normalizedHeight)
            {
                return 0.05 + PositivePow(cloudDensity, Remap(normalizedHeight, 0.3, 0.85, 0.5, 2.0));
            }
            #define MSCOUNT 3
            struct ParticipatingMediaContext
            {
	            float3 ScatteringCoefficients[MSCOUNT];
	            float3 ExtinctionCoefficients[MSCOUNT];
	            float3 TransmittanceToLight0[MSCOUNT];
            };
            struct ParticipatingMediaPhaseContext
            {
	            float Phase0[MSCOUNT];
            };
            ParticipatingMediaContext SetupParticipatingMediaContext(float3 BaseAlbedo, float3 BaseExtinctionCoefficients, 
            float MsSFactor, float MsEFactor, float3 InitialTransmittanceToLight0)
            {
                
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
            float HenyeyGreensteinPhase(float cosAngle, float g)
            {
                float g2 = g * g;
                return (1.0 / (4.0 * PI)) * (1.0 - g2) / PositivePow(1.0 + g2 - 2.0 * g * cosAngle, 1.5);
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
            float hgPhase(float g, float cosTheta)
            {
                float numer = 1.0f - g * g;
                float denom = 1.0f + g * g + 2.0f * g * cosTheta;
                return numer / (4.0f * PI * denom * sqrt(denom));
            }

            float dualLobPhase(float g0, float g1, float w, float cosTheta)
            {
                return lerp(hgPhase(g0, cosTheta), hgPhase(g1, cosTheta), w);
            }
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
            float3 EvaluateSunColor(EnvironmentLighting envLighting, float relativeRayDistance)
            {
                return lerp(envLighting.sunColor0, envLighting.sunColor1, relativeRayDistance);
            }
			  //射线与包围盒相交, x 到包围盒最近的距离， y 穿过包围盒的距离
            float2 RayBoxDst(float3 boxMin, float3 boxMax, float3 pos, float3 rayDir)
            {
                float3 t0 = (boxMin - pos) / rayDir;
                float3 t1 = (boxMax - pos) / rayDir;
                
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                
                //射线到box两个相交点的距离, dstA最近距离， dstB最远距离
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(min(tmax.x, tmax.y), tmax.z);
                
                float dstToBox = max(0, dstA);
                float dstInBox = max(0, dstB - dstToBox);
                
                return float2(dstToBox, dstInBox);
            }
            float GetDirectScatterProbability(float eccentricity, float CosTheta)
            {
                return max(HenyeyGreensteinPhase(CosTheta, eccentricity), _SilverIntensity * HenyeyGreensteinPhase(CosTheta, 0.99 - 0.5));
            }
            void EvaluateVolumetricShadow(float3 samplePos, float3 sunDirection, inout ParticipatingMediaContext PMC , float3 minbox, float3 maxbox)
            {
                    // Compute the Ray to the limits of the cloud volume in the direction of the light

                   
                   
                    float2 LightRayBox   = RayBoxDst(minbox,maxbox,samplePos,sunDirection);
                    float  totalLightDistance   = LightRayBox.y;
                    float3 lightSamplePos =  samplePos;
                    float  intervalSize   =  _LightStepSize ;
                    
                    // For Suming the extiction
                    float ExtinctionAcc[MSCOUNT];
                    int ms;
                    for (ms = 0; ms < MSCOUNT; ++ms)
                    {
                        ExtinctionAcc[ms] = 0.0f;
                    }

                    // Todo:using transmittanceShadowMap for Raymarching Optimaztion
                    for (int j = 0; j < 6; j++)
                    {
                        


                        
                       
                        // Evaluate the current sample point
                        

                        
                        float LightDensity =  SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, lightSamplePos).r *_LightDensityScale;
                        
                        float sampledSigmaT = LightDensity ;

                        // Evaluate ExtinctionCofficients to sum the extiction
                        ParticipatingMediaContext ShadowPMC = SetupParticipatingMediaContext(_Albedo, sampledSigmaT, _MsScattFactor, _MsExtinFactor, 1.0f);

                        for(ms = 0; ms < MSCOUNT; ++ms)
                        {
                            ExtinctionAcc[ms] += max(ShadowPMC.ExtinctionCoefficients[ms].x, 1e-6f);
                        }
                        
                         lightSamplePos += sunDirection * intervalSize;
                        
                    }
                    // Compute the VolumetricShadow to Light
                    UNITY_UNROLL
                    for(ms = 0; ms < MSCOUNT; ++ms)
                    {
                        PMC.TransmittanceToLight0[ms] *= exp(-ExtinctionAcc[ms] * intervalSize);
                        //PMC.TransmittanceToLight0[ms]   *= max(exp(-ExtinctionAcc[ms] * intervalSize), exp(-ExtinctionAcc[ms] * intervalSize * 0.25) * 0.7);
                    }
            }

            void EvaluateLuminance(in EnvironmentLighting envLighting, in ParticipatingMediaContext PMC, in float normalizedHeight,float inscattering_probality, float stepSize, float relativeRayDistance,
            inout float4 cloudResult)
            {
                // L = sum(Li) where i = 0,..., MSCOUNT-1
                // Li = sigmaS[i] * Light(wi) * phase[ms] * TransmittanceToLight[ms] * in_scatteringP;
                float3 Luminance = float3(0.0, 0.0, 0.0);
                for (int ms = MSCOUNT - 1; ms >= 0; --ms)
                {
                    float3 ScatteringCoefficients =  PMC.ScatteringCoefficients[ms];
                    float  ExtinctionCoefficients  = PMC.ExtinctionCoefficients[ms].x;
                    float  TransmittanceToLight    = PMC.TransmittanceToLight0[ms].x;

                    float3 SunColor               = envLighting.sunColor0;
                    
                    float3 SunLuminance           = TransmittanceToLight * inscattering_probality * SunColor * envLighting.cloudPMPC.Phase0[ms] * _SilverIntensity;

                    float3 AmbientLuminance = (ms == 0 ? (lerp(envLighting.ambientTermTop * saturate(_AmbientLightingBottomVisibility + normalizedHeight), 
                        envLighting.ambientTermBottom, normalizedHeight)) : float3(0.0f, 0.0f, 0.0f));

                    AmbientLuminance *= _AmbientOcclusion;
                    AmbientLuminance *= _AmbientLuminanceIntensity;

                    float3 ScatteredLuminance = (SunLuminance + AmbientLuminance) * ScatteringCoefficients;

                    // Improved scattering integration. See slide 29 of "Physically Based and Unified Volumetric Rendering in Frostbite"
                    float SafeExtinctionThreshold = 0.000001f;
                    float SafeExtinctionCoefficients = max(SafeExtinctionThreshold, PMC.ExtinctionCoefficients[ms].x);
                    float SafePathSegmentTransmittance = exp(-SafeExtinctionCoefficients * stepSize);
                    //float SafePathSegmentTransmittance = max(exp(-SafeExtinctionCoefficients * stepSize), exp(-SafeExtinctionCoefficients * stepSize * 0.25) * 0.7);
                    float3 LuminanceIntegral = cloudResult.a *ScatteredLuminance *stepSize;
                    //float3 LuminanceContribution = cloudResult.a * LuminanceIntegral;
                    Luminance += LuminanceIntegral;
                
                    if (ms == 0)
                    {
                        cloudResult.a *= SafePathSegmentTransmittance;
                    }
                }

                cloudResult.rgb += Luminance;
            } 

#endif
