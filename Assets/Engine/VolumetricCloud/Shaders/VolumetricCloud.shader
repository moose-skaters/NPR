Shader "Sky/VolumetricClouds"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" { }

        _TransmittanceLutTexture("_TransmittanceLutTexture", 2D) = "white" {}
        _ClouTypeTexture("_ClouTypeTexture",2D) = "black" {}
        _BlueNoise2D("_BlueNoise2D", 2D) = "white" {}

        _CloudMapTexture("_CloudMapTexture", 2D) = "white" {}
        _CloudLutTexture("_CloudLutTexture", 2D) = "white" {}

       
        
        _ErosionNoise("_ErosionNoise", 3D) =  "white"  {}
       
        _Worley128RGBA("_Worley128RGBA",3D)  = "white" {}
        
       
    }

    HLSLINCLUDE
       
        #include "./VolumetricCloudsUtilitiesPS.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        // Pass 0
        Pass
        {
            Name "DownscaleDepthCheckerBoardMinAndMax"

            Blend One Zero
            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            TEXTURE2D(_DepthTexture);

            void Frag(Varyings input, out float DepthCheckerBoardMinAndMax : SV_Target0)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Pixel coordinate for the output 
                uint2 DstPixelPos = input.positionCS.xy; // IntermediateCoord
                // Lower left corner from the input 2x2 quad
                uint2 SrcPixelPos = DstPixelPos * 2;
                // DownsampleDepth
                float depth0 = LOAD_TEXTURE2D_X(_DepthTexture, SrcPixelPos + int2(0, 0)).x;
                float depth1 = LOAD_TEXTURE2D_X(_DepthTexture, SrcPixelPos + int2(0, 1)).x;
                float depth2 = LOAD_TEXTURE2D_X(_DepthTexture, SrcPixelPos + int2(1, 1)).x;
                float depth3 = LOAD_TEXTURE2D_X(_DepthTexture, SrcPixelPos + int2(1, 0)).x;

                // OUTPUT_MIN_AND_MAX_DEPTH
                float depthMin = min(min(depth0, depth1), min(depth2, depth3));
                float depthMax = max(max(depth0, depth1), max(depth2, depth3));

                // OUTPUT_CHECKERBOARD_MIN_AND_MAX_DEPTH
                const uint2 PixelPosStep = (DstPixelPos >> 1) * 2; 
                uint CheckerBoard = (DstPixelPos.x - PixelPosStep.x);								    // horizontal alternance of black and white
                CheckerBoard = (DstPixelPos.y - PixelPosStep.y) == 0 ? CheckerBoard : 1 - CheckerBoard;// vertical toggle of horizontal checker on odd lines

                DepthCheckerBoardMinAndMax = CheckerBoard > 0 ? depthMax : depthMin ;

            }

            ENDHLSL

        }

        // Pass 1
        Pass
        {
            Name "Volumetric Clouds Tracing"
            Blend One Zero
            Cull  Off ZWrite Off ZTest Always

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.5
            
            #pragma multi_compile_local_fragment _ LOCAL_VOLUMETRIC_CLOUDS

            void Frag(Varyings input, out float4 CloudsLighting : SV_Target0, out float CloudsDepth : SV_Target1)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                uint2 traceCoord = input.positionCS.xy;

                // Depending on if we are in full res or not, use a different intermediate coord
                uint2 intermediateCoord = traceCoord.xy; // Full resolution case || traceCoord == FullRes
                if (_LowResolutionEvaluation)
                {
                    if (_EnableIntegration) // Quater resolution case || traceCoord is QuatResInHalfResCheckerBoard, intermediateSize == HalfRes
                    {
                        // Compute the half res coordinate that matches this thread (as we virtually do the computation in half res space)
                        int checkerBoardIndex = ComputeCheckerBoardIndex(traceCoord.xy, _SubPixelIndex);
                        intermediateCoord = traceCoord.xy * 2 + HalfResolutionIndexToOffset(checkerBoardIndex);
                    }
                    else // Half resolution case || traceCoord == HalfRes, intermediateCoord == FullRes
                    {
                        intermediateCoord = traceCoord.xy * 2; 
                        
                    }
                }

                ComputeCloudLightingAndDepth(intermediateCoord, CloudsLighting, CloudsDepth);
            }

            ENDHLSL
        }

        // Pass 2
        Pass
        {
            Name "Volumetric Clouds QuaterResMode Denoise"

            Blend One Zero
            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM
            
            #include "./VolumetricCloudsBilateralUpsample.hlsl"
            #include "./VolumetricCloudsDenoising.hlsl"

            TEXTURE2D(_HistoryVolumetricClouds0Texture);
            TEXTURE2D(_HistoryVolumetricClouds1Texture);
            //SAMPLER(s_linear_clamp_sampler);
            
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.5

            #pragma multi_compile_local_fragment _ LOCAL_VOLUMETRIC_CLOUDS

            // Reproject other 3 pixels in one tile(2x2) of HalfResIntermidate By tracingResult(1 pixel in one tile(2x2)) and previousResult 
            void Frag(Varyings input, out float4 CloudsLighting : SV_Target0, out float3 CloudsAdditional : SV_Target1)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Compute the set of coordinates we need
                uint2 intermediateCoord = input.positionCS.xy; 
                uint2 fullResCoord = intermediateCoord * 2; 
                uint2 traceCoord = intermediateCoord / 2; 

                // Load the depth of the clouds
                float currentCloudDepth = LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord).x; 

                // Compute the motionVector of the clouds
                float3 currentCloudPixelWorldPos;
                float2 NDCxy = float2((intermediateCoord + float2(0.5, 0.5)) / _IntermediateSizeXY);
#ifdef LOCAL_VOLUMETRIC_CLOUDS
                float2 motionVector = EvaluateCloudMotionVector(NDCxy, currentCloudDepth, currentCloudPixelWorldPos); // NDCSpace
#else
                // If we are processing clouds as distant, we have no choice but to consider them very far.
                float2 motionVector = EvaluateCloudMotionVector(NDCxy, UNITY_RAW_FAR_CLIP_VALUE, currentCloudPixelWorldPos);
#endif

                // Compute the history pixel coordinate to tap from
                float2 historyCoord = (intermediateCoord + 0.5) - motionVector * _IntermediateSizeXY; 
                float2 clampedHistoryUV = clamp(historyCoord, 0.0, _IntermediateSizeXY - 0.5f) / _IntermediateSizeXY; 

                // Todo: 1.ratioScale
                // float2 ratioScale = _HistoryViewportSize / _HistoryBufferSize;
                // float2 historySampleCoords = clampedHistoryUV * ratioScale;

                // Grab the history values
                float4 previousResult = SAMPLE_TEXTURE2D_X_LOD(_HistoryVolumetricClouds0Texture, s_linear_clamp_sampler, clampedHistoryUV, 0); // [inscattering, transmittance]
                float3 previousResult1 = SAMPLE_TEXTURE2D_X_LOD(_HistoryVolumetricClouds1Texture, s_linear_clamp_sampler, clampedHistoryUV, 0).rgb; // [sampleCount, currentPixelSceneDepth, cloudDepth]

                // Todo: 2.exposure
                // Inverse the exposure of the previous frame and apply current one (need to be done in linear space)
                // previousResult.xyz *= GetInversePreviousExposureMultiplier() * GetCurrentExposureMultiplier();

                // Unpack the second depthData buffer
                float previousSampleCount = previousResult1.x; 
                float previousDepth = previousResult1.y; 
                float previousCloudDepth = previousResult1.z; 

                // This tracks if the history is considered valid
                // case1: previousSampleCount == 0
                // case2: historyCoord is invalid
                // case3: currentPixelDepth is too different from previous
                bool validHistory = previousSampleCount >= 0.5f; // case1

                // The history is invalid if we are requesting a value outside the frame
                if(historyCoord.x < 0.0 || historyCoord.x >= _IntermediateSizeXY.x || historyCoord.y < 0.0 || historyCoord.y >= _IntermediateSizeXY.y)
                    validHistory = false;  // case2

                // Read the depth of the current pixel
                float currentDepth = LOAD_TEXTURE2D_X(_HalfResDepthBuffer, intermediateCoord).x; 

                // Compare the depth of the current pixel to the one of its history, if they are too different, we cannot consider this history valid
                float linearPrevDepth = Linear01Depth(previousDepth, _ZBufferParams);
                float linearCurrentDepth = Linear01Depth(currentDepth, _ZBufferParams);

                // We need to check if the pixel depth coherence if the clouds can be behind and in front of the pixel
                if (abs(linearPrevDepth - linearCurrentDepth) > linearCurrentDepth * 0.2)
                    validHistory = false; // case3

                // Compute the local index that tells us the index of this pixel, the strategy for reprojection is a bit different in both cases
                int localIndex = (intermediateCoord.x & 1) + (intermediateCoord.y & 1) * 2; 
                int currentIndex = ComputeCheckerBoardIndex(intermediateCoord / 2, _SubPixelIndex); 
                float validityFactor = 1.0;

                if (localIndex == currentIndex) // Case0: CurrentTracingIndex Use tracing result
                {
                    // We need to validate that within the 3x3 trace region, at least one of the pixels is not a background pixel (incluing the clouds)
                    float cloudNeighborhood = 0.0f;
                    for (int y = -1; y <= 1; ++y)
                    {
                        for (int x = -1; x <= 1; ++x)
                        {
                            // cloudDepth == UNITY_RAW_FAR_VALUE / MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE means background(sky), else means occlusion or clouds
                        #ifdef LOCAL_VOLUMETRIC_CLOUDS
                            if (LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + int2(x, y)).x != 0.0f)
                                cloudNeighborhood += 1.0f;
                        #else
                            if (LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + int2(x, y)).x != MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE)
                                cloudNeighborhood += 1.0f;
                        #endif
                        }
                    }

                    // If the target coordinate is out of the screen, we cannot use the history
                    float accumulationFactor = 0.0;
                    float sampleCount = 1.0;
                    if (validHistory && cloudNeighborhood != 0.0f)
                    {
                        // Define our accumation value
                        accumulationFactor = previousSampleCount >= 16.0 ? 0.94117647058 : (previousSampleCount / (previousSampleCount + 1.0));
                        accumulationFactor *= _TemporalAccumulationFactor * validityFactor * _CloudHistoryInvalidation;
                        sampleCount = min(previousSampleCount + 1.0, 16.0); // max 16 sampledFrames
                    }

                    // Accumulate the result with the previous frame (TAA) 
                    previousResult = accumulationFactor * previousResult + (1.0 - accumulationFactor) * LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord);
                    // UE
                    //previousResult = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord);
                    
                    // DepthOutput    
                    previousSampleCount = sampleCount;
                    // If there are no clouds in the new pixel, we force the depth to zero. Otherwise, we are likely on a pixel
                    // which state is not stable and we take the maximum of both frames as we cannot interpolate between the depths.
                    #ifdef LOCAL_VOLUMETRIC_CLOUDS
                        previousCloudDepth = previousResult.w == 1.0 ? UNITY_RAW_FAR_CLIP_VALUE : currentCloudDepth;
                    #else
                        previousCloudDepth = previousResult.w == 1.0 ? MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE : currentCloudDepth;
                    #endif

                }
                else
                {
                    // Reduce the history validity a bit
                    previousSampleCount *= validityFactor * _CloudHistoryInvalidation; // DepthOutput0

                    // If the target coordinate is out of the screen or the depth that was used to generate it
                    // is too different from the one of the current pixel, we cannot use the history
                    if (!validHistory) // Case1: Invalidhistory Use nearest depth sample from neighboord
                    {
                        // Structure that will hold everything
                        NeighborhoodUpsampleData3x3 upsampleData; //[Neighborhood3x3CloudsLighting, SceneDeviceZ, DistanceBasedWeight]
                        FillCloudReprojectionNeighborhoodData_NOLDS(traceCoord, localIndex, upsampleData);

                        // Exclude Large DepthDiff Neighborhood Pixel by override mask valus to false, 
                        // and also get the closest neighborhood result by closestNeighborIndex
                        float rejectNeighborhood = 0.0f;
                        int closestNeighbor = 4;
                        OverrideMaskValues(currentDepth, upsampleData, rejectNeighborhood, closestNeighbor);

                        // If rejectNeighborhood == 0 means at least one neighbor value can be used, rejectNeighborhood == 1.0f means all failed
                        // previousSampleCount 1.0 means we were able to produce a value 0.0 means we failed to
                        previousSampleCount = 1.0f - rejectNeighborhood;
                        if (rejectNeighborhood == 1.0f)
                        {
                            // We don't have any valid history and there is no neighbor that is usable, we consider that we have no clouds.
                            previousResult = float4(0.0, 0.0, 0.0, 1.0);
                            previousSampleCount = 0.0f;

                            // Use nearest sample from neighboord
                            //previousResult = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + IndexToLocalOffsetCoords[closestNeighbor]); 
                            //previousSampleCount = 0.0f;
                        }
                        else
                        {
                            // We don't have any history for this pixel, but there is at least one closest neighbor that can be used in the current frame tracing
                            previousSampleCount = 1.0f;
                            // HDRP
                            previousResult = BilUpColor3x3(currentDepth, upsampleData);
                            // UE
                            //previousResult = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + IndexToLocalOffsetCoords[closestNeighbor]); 

                            // Due to numerical precision issues, upscaling a bunch of 1.0 can lead to a slightly lower number, this fixes it.
                            if (EvaluateRegionEmptiness(upsampleData) == 1.0)
                                previousResult = float4(0, 0, 0, 1);
                        }

                        //previousResult = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + IndexToLocalOffsetCoords[closestNeighbor]); 
                        previousCloudDepth = LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + IndexToLocalOffsetCoords[closestNeighbor]).x; // DepthOutput2
                    } 
                    else // Case3: ValidPrevious Clip Previous Cloudlighting Result / Clamp CloudDepth/Transmittance Result by AABB
                    {
                        float4 lightingMin = FLT_MAX;
                        float4 lightingMax = -FLT_MAX;
                        float depthsMin = FLT_MAX;
                        float depthsMax = -FLT_MAX;
                        for (int y = -1; y <= 1; ++y)
                        {
                            for (int x = -1; x <= 1; ++x)
                            {
                                // CloudLighting
                                float4 neighboorCloudLigtingData = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(x, y));
                                lightingMin = min(lightingMin, neighboorCloudLigtingData);
                                lightingMax = max(lightingMax, neighboorCloudLigtingData);
                                // CloudDepthDeviceZ
                                float neighboorDepthData = LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + int2(x, y)).x;
                                #ifdef LOCAL_VOLUMETRIC_CLOUDS
                                    neighboorDepthData = LinearEyeDepth(neighboorDepthData.x, _ZBufferParams); // Covert to Linear space
                                    depthsMin = min(depthsMin, neighboorDepthData);
                                    depthsMax = max(depthsMax, neighboorDepthData);
                                #else
                                    depthsMin = min(depthsMin, neighboorDepthData);
                                    depthsMax = max(depthsMax, neighboorDepthData);
                                #endif
                            }
                        }
                        // Clip previousCloudLighting by AABB HDRP
                        previousResult = ClipCloudsToRegion(previousResult, lightingMin, lightingMax, validityFactor);
                        // Clamp previousCloudLighting by AABB UE
                        //previousResult = clamp(previousResult, lightingMin, lightingMax);
                        // Clamp previousCloudDepth by AABB UE
                        #ifdef LOCAL_VOLUMETRIC_CLOUDS
                            float cloudDepthPrevLinear = LinearEyeDepth(previousCloudDepth, _ZBufferParams); 
                            cloudDepthPrevLinear = clamp(cloudDepthPrevLinear, depthsMin, depthsMax); 
                            // Convert linear to deviceZ
                            float3 rayDir = normalize(currentCloudPixelWorldPos - _WorldSpaceCameraPos.xyz);
                            float cloudDepthPrevDeviceZ = ConvertCloudDepth(_WorldSpaceCameraPos.xyz + rayDir * cloudDepthPrevLinear);
                            previousCloudDepth = cloudDepthPrevDeviceZ; // DepthOutput2
                        #else
                            previousCloudDepth = clamp(previousCloudDepth, depthsMin, depthsMax); 
                        #endif
                    } 
                }

                // Make sure this doesn't go outside of the [0, 1] interval
                previousResult.w = saturate(previousResult.w);
                previousDepth = currentDepth; 
                // Output
                CloudsLighting = previousResult;
                CloudsAdditional = float3(previousSampleCount, previousDepth, previousCloudDepth);
            }


            ENDHLSL
        }
        
        // Pass 3
        Pass
        {
            Name "Volumetric Clouds Upsample And Combine"
            // Blend One Zero
            Blend One SrcAlpha, Zero One
            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM

            #include "./VolumetricCloudsBilateralUpsample.hlsl"
            #include "./VolumetricCloudsDenoising.hlsl"
            #include "./VolumeRendering.hlsl"

            TEXTURE2D(_SceneDepthTexture);

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.5
            #pragma multi_compile_local_fragment _ LOCAL_VOLUMETRIC_CLOUDS

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                uint2 finalCoord = input.positionCS.xy;
                uint2 halfResCoord = finalCoord / 2;

                // 1.Upsampling Pass
                // Grab the depth value of the pixel
                float highDepth = LOAD_TEXTURE2D_X(_SceneDepthTexture, finalCoord.xy).x;

                // Compute the index of the pixel in the 2x2 region (L->R, T->B)
                uint subRegionIndex = (finalCoord.x & 1) + (finalCoord.y & 1) * 2;

                // Structure that will hold everything 3x3
                NeighborhoodUpsampleData3x3 upsampleData;
                FillCloudUpscaleNeighborhoodData_NOLDS(halfResCoord, subRegionIndex, upsampleData);

#ifdef LOCAL_VOLUMETRIC_CLOUDS
                // Flag that tells us which pixel holds valid information
                float rejectedNeighborhood = 0.0;
                int closestNeighbor = 4;
                OverrideMaskValues(highDepth, upsampleData, rejectedNeighborhood, closestNeighbor);

                // Bilateral upscale
                float4 currentClouds = BilUpColor3x3(highDepth, upsampleData);

                // Read the fallback value and use it if we defined that it was impossible for us to do something about it
                if (rejectedNeighborhood == 1.0f)
                    currentClouds = float4(0.0, 0.0, 0.0, 1.0);
#else
                upsampleData.lowDepthA = UNITY_RAW_FAR_CLIP_VALUE;
                upsampleData.lowDepthB = UNITY_RAW_FAR_CLIP_VALUE;
                upsampleData.lowDepthC = UNITY_RAW_FAR_CLIP_VALUE;
                float4 currentClouds = highDepth == UNITY_RAW_FAR_CLIP_VALUE ? BilUpColor3x3(highDepth, upsampleData) : float4(0.0, 0.0, 0.0, 1.0);
#endif
                // De-tonemap the inscattering value
                currentClouds.w = saturate(currentClouds.w);

                // Due to numerical precision issues, upscaling a bunch of 1.0 can lead to a slightly lower number, this fixes it.
                if (EvaluateRegionEmptiness(upsampleData) == 1.0)
                    currentClouds = float4(0, 0, 0, 1);
                
                // Todo: 2.Postprocess Pass
                // 2.1 HeightFog Effect
                
                if (_FogEnabled)
                {
                    // cloudDepth
                #ifdef LOCAL_VOLUMETRIC_CLOUDS
                    float cloudDepth = currentClouds.w != 1.0 ? EvaluateUpscaledCloudDepth_NOLDS(halfResCoord, upsampleData) : UNITY_RAW_FAR_CLIP_VALUE;
                #else
                    float cloudDepth = UNITY_RAW_FAR_CLIP_VALUE;
                #endif

                #ifdef LOCAL_VOLUMETRIC_CLOUDS
                    // cloudDistance
                    float3 cloudWorldPos = ComputeWorldSpacePosition(float2((finalCoord.xy + 0.5) / _FinalSizeXY.xy), cloudDepth, UNITY_MATRIX_I_VP);
                    float3 viewDir = normalize(cloudWorldPos - _WorldSpaceCameraPos.xyz);
                #else
                    float3 cloudWorldPos = ComputeWorldSpacePosition(float2((finalCoord.xy + 0.5) / _FinalSizeXY.xy), cloudDepth, UNITY_MATRIX_I_VP);
                    float3 viewDir = normalize(cloudWorldPos - _WorldSpaceCameraPos.xyz);
                    float cloudDistance = EvaluateUpscaledCloudDepth_NOLDS(halfResCoord, upsampleData);
                    cloudWorldPos = _WorldSpaceCameraPos.xyz + viewDir * cloudDistance;
                #endif
                    // Calculate HeightFog Effect
                    float4 HeightFogInscatteringAndTransmittance = CalculateHeightFog(cloudWorldPos - _WorldSpaceCameraPos.xyz);

                    currentClouds.xyz = HeightFogInscatteringAndTransmittance.a * currentClouds.xyz  + 
                                        HeightFogInscatteringAndTransmittance.rgb * (1.0 - currentClouds.a);

                }
                // 2.2 AerialPerspective Effect

                // 2.3 VolumetricLight Effect
                
                // Upscale Output
                // CloudsLightingUpscale = currentClouds;
                
                // Combine Pass
                // (currentClouds.rgb + currentClouds.w * cameraColor.rgb, cameraColor.a);
                return currentClouds;
            }

            ENDHLSL
        }

        // Pass 4
        Pass
        {
            Name "Volumetric Clouds Combine"
            // (CloudData.rgb + CloudData.a * CameraColor.rgb, CameraColor.a)
            Blend One SrcAlpha, Zero One

            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D(_VolumetricCloudsUpscaleTexture); SAMPLER(sampler_VolumetricCloudsUpscaleTexture);

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 cloudData = SAMPLE_TEXTURE2D(_VolumetricCloudsUpscaleTexture, sampler_VolumetricCloudsUpscaleTexture, input.texcoord);
                return cloudData;
            }

            ENDHLSL
        }

        // Pass 5
        Pass
        {
            Name "Volumetric Clouds HalfResMode Denoise "

            Blend One Zero
            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM

            #include "./VolumetricCloudsBilateralUpsample.hlsl"
            #include "./VolumetricCloudsDenoising.hlsl"
            #pragma multi_compile_local_fragment _ LOCAL_VOLUMETRIC_CLOUDS

            TEXTURE2D(_HistoryVolumetricClouds0Texture);
            TEXTURE2D(_HistoryVolumetricClouds1Texture);
            //SAMPLER(s_linear_clamp_sampler);

            #pragma vertex Vert
            #pragma fragment Frag

            void Frag(Varyings input, out float4 CloudsLighting : SV_Target0, out float3 CloudsAdditional : SV_Target1)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                // Compute the set of coordinates we need
                uint2 intermediateCoord = input.positionCS.xy;  
                uint2 fullResCoord = intermediateCoord * 2;
                uint2 traceCoord = intermediateCoord;
                
                // Load the depth of the clouds
                float currentCloudDepth = LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord).x; 

                // Compute the motionVector of the clouds
                float3 currentCloudPixelWorldPos;
                float2 NDCxy = float2((intermediateCoord + float2(0.5, 0.5)) / _IntermediateSizeXY);
#ifdef LOCAL_VOLUMETRIC_CLOUDS
                float2 motionVector = EvaluateCloudMotionVector(NDCxy, currentCloudDepth, currentCloudPixelWorldPos); // NDCSpace
#else
                // If we are processing clouds as distant, we have no choice but to consider them very far.
                float2 motionVector = EvaluateCloudMotionVector(NDCxy, UNITY_RAW_FAR_CLIP_VALUE, currentCloudPixelWorldPos);
#endif
                // Compute the history pixel coordinate to tap from
                float2 historyCoord = (intermediateCoord + 0.5) - motionVector * _IntermediateSizeXY; 
                float2 clampedHistoryUV = clamp(historyCoord, 0.0, _IntermediateSizeXY - 0.5f) / _IntermediateSizeXY; 

                // Todo: 1.ratioScale
                // float2 ratioScale = _HistoryViewportSize / _HistoryBufferSize;
                // float2 historySampleCoords = clampedHistoryUV * ratioScale;

                // Grab the history values
                float4 previousResult = SAMPLE_TEXTURE2D_X_LOD(_HistoryVolumetricClouds0Texture, s_linear_clamp_sampler, clampedHistoryUV, 0); // [inscattering, transmittance]
                float3 previousResult1 = SAMPLE_TEXTURE2D_X_LOD(_HistoryVolumetricClouds1Texture, s_linear_clamp_sampler, clampedHistoryUV, 0).rgb; // [sampleCount, currentPixelSceneDepth, cloudDepth]

                // Todo: 2.exposure
                // Inverse the exposure of the previous frame and apply current one (need to be done in linear space)
                // previousResult.xyz *= GetInversePreviousExposureMultiplier() * GetCurrentExposureMultiplier();

                // Unpack the second depthData buffer
                float previousSampleCount = previousResult1.x; 
                float previousDepth = previousResult1.y; 
                float previousCloudDepth = previousResult1.z; 

                // This tracks if the history is considered valid
                // case2: historyCoord is invalid
                // case3: currentPixelDepth is too different from previous
                bool validHistory = true; 
                // The history is invalid if we are requesting a value outside the frame
                if(historyCoord.x < 0.0 || historyCoord.x >= _IntermediateSizeXY.x || historyCoord.y < 0.0 || historyCoord.y >= _IntermediateSizeXY.y)
                {
                    validHistory = false;  // case2
                }
                    
                // Read the depth of the current pixel
                float currentDepth = LOAD_TEXTURE2D_X(_FullResDepthBuffer, fullResCoord).x;

                // Compare the depth of the current pixel to the one of its history, if they are too different, we cannot consider this history valid
                float linearPrevDepth = Linear01Depth(previousDepth, _ZBufferParams);
                float linearCurrentDepth = Linear01Depth(currentDepth, _ZBufferParams);

                // We need to check if the pixel depth coherence if the clouds can be behind and in front of the pixel
                if (abs(linearPrevDepth - linearCurrentDepth) > linearCurrentDepth * 0.2)
                    validHistory = false; // case3

                float validityFactor = 1.0;
                if (validHistory)
                {
                    // We need to validate that within the 3x3 trace region, at least one of the pixels is not a background pixel (incluing the clouds)
                    float cloudNeighborhood = 0.0f;
                    int x, y;
                    for (y = -1; y <= 1; ++y)
                    {
                        for (x = -1; x <= 1; ++x)
                        {
                            // cloudDepth == UNITY_RAW_FAR_VALUE / MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE means background(sky), else means occlusion or clouds
                            #ifdef LOCAL_VOLUMETRIC_CLOUDS
                                if (LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + int2(x, y)).x != 0.0f)
                                    cloudNeighborhood += 1.0f;
                            #else
                                if (LOAD_TEXTURE2D_X(_CloudsDepthTexture, traceCoord + int2(x, y)).x != MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE)
                                    cloudNeighborhood += 1.0f;
                            #endif
                        }
                    }

                    // If the target coordinate is out of the screen, we cannot use the history
                    float accumulationFactor = 0.0;
                    float sampleCount = 1.0;
                    // Define our accumation value
                    if (validHistory && cloudNeighborhood != 0.0f)
                    {
                        // Define our accumation value
                        accumulationFactor = previousSampleCount >= 16.0 ? 0.94117647058 : (previousSampleCount / (previousSampleCount + 1.0));
                        accumulationFactor *= _TemporalAccumulationFactor * validityFactor * _CloudHistoryInvalidation;
                        sampleCount = min(previousSampleCount + 1.0, 16.0); // max 16 sampledFrames
                    }
                    
                    // Re-projected color from last frame.
                    float4 lightingMin = FLT_MAX;
                    float4 lightingMax = -FLT_MAX;
                    for (y = -1; y <= 1; ++y)
                    {
                        for (x = -1; x <= 1; ++x)
                        {
                            // CloudLighting
                            float4 neighboorCloudLigtingData = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord + int2(x, y));
                            lightingMin = min(lightingMin, neighboorCloudLigtingData);
                            lightingMax = max(lightingMax, neighboorCloudLigtingData);
                        }
                    }
                    // Clip previousCloudLighting by AABB
                    previousResult = ClipCloudsToRegion(previousResult, lightingMin, lightingMax, validityFactor);
                    previousResult = accumulationFactor * previousResult + (1.0 - accumulationFactor) * LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord);
                    previousSampleCount = sampleCount;
                } 
                else 
                {
                    previousResult = LOAD_TEXTURE2D_X(_CloudsLightingTexture, traceCoord);
                    previousSampleCount = 0.0f;
                }

                // Make sure this doesn't go outside of the [0, 1] interval
                previousResult.w = saturate(previousResult.w);
                previousDepth = currentDepth;
                previousCloudDepth = currentCloudDepth;
                // Accumulate the result with the previous frame
                CloudsLighting = previousResult;
                CloudsAdditional = float3(previousSampleCount, previousDepth, previousCloudDepth);
            }
            

            ENDHLSL
        }

    }
}
