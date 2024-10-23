Shader "Unlit/VolumetricSimple"
{
    Properties
    {
        _VolumeTex("VolumeTex", 3D) = "white" {}
       
        _NumSteps("NumSteps", Float) = 64
        _NumLightSteps("_NumLightSteps", Float) = 8
        _StepSize("_StepSize", Float) = 0.02
        _LightStepSize("_LightStepSize", Float) = 0.06
        _DensityScale("_DensityScale", Float) = 0.5
        _LightDensityScale("_LightDensityScale",float) = 0.5
        _Offset("_Offset", Vector) = (0.5, 0.5, 0.5)
        _Albedo("_Albedo", Color) = (1, 1, 1, 1)
        _MsScattFactor("MsScattFactor", Float) = 0.5
        _MsExtinFactor("MsExtinFactor", Float) = 0.5
        _MsPhaseFactor("MsPhaseFactor", Float) = 0.5
        _AmbientLightingTint("_AmbientLightingTint",Color) = (1,1,1,1)
        _PhaseG0("_PhaseG0",Range(-1,1)) = 0.7
        _PhaseG1("_PhaseG0",Range(-1,1)) = 0.7
        _PhaseBlendWeight("_PhaseBlendWeight",Range(0,1)) = 0.5
        _SilverIntensity("_SilverIntensity",Range(0,10)) = 8
        _AmbientOcclusion("_AmbientOcclusion" , Range(0,1)) = 1
        _AmbientLightingBottomVisibility("_AmbientLightingBottomVisibility",Range(0,1)) = 1
        _AmbientLuminanceIntensity("_AmbientLuminanceIntensity",Range(0,1)) = 1
        _InscatteringIntensity("_InscatteringIntensity",Range(0,1)) = 0.1
        
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _NumSteps;
        float _NumLightSteps;
        float _DensityScale;
        float _LightDensityScale;
        float _StepSize;
        float _LightStepSize;
        float _DarknessThreshold;
        float3 _Offset;
        float _LightAbsorb;
        float _Transmittance;
        float3 _ShadowColor;
        float3 _Color;
        
        float3 _Albedo;
        float _MsScattFactor;
        float _MsExtinFactor;
        float _MsPhaseFactor;
        float3 _AmbientLightingTint;
        float _PhaseG0;
        float _PhaseG1;
        float _PhaseBlendWeight;
        float _SilverIntensity;
        float _AmbientLightingBottomVisibility;
        float _AmbientLuminanceIntensity;
        float _AmbientOcclusion;
        float _InscatteringIntensity;

        float3 _MinBox;
        float3 _MaxBox;

       
        CBUFFER_END
        
        TEXTURE3D(_VolumeTex);
        SAMPLER(sampler_VolumeTex);

      

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float4 texcoord : TEXCOORD0;
            float3 positionOS : TEXCOORD1;
            float3 CameraPosOS : TEXCOORD2;
        };

        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull  Off
            Blend One SrcAlpha, Zero One
            ZTest LEqual
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex VERT
            #pragma target 2.0
            #pragma fragment FRAG

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "VolumetricCloudsLib.hlsl"
            v2f VERT(a2v input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.CameraPosOS= TransformWorldToObject(_WorldSpaceCameraPos);
                output.texcoord.xy = input.texcoord;
                output.positionOS = input.positionOS.xyz;
                return output;
            }
          

            bool IsOutOfBound(float3 samplePos,float3 boundMin,float3 boundMax) {
                if(samplePos.x > boundMax.x || samplePos.x < boundMin.x)
                    return true;

                if(samplePos.y > boundMax.y || samplePos.y < boundMin.y)
                    return true;

                if(samplePos.z > boundMax.z || samplePos.z < boundMin.z)
                    return true;

                return false;
            }
            
            float PowderEffect(float cloudDensity, float cosAngle, float intensity)
            {
                float powderEffect = 1.0 - exp(-cloudDensity * 4.0);
                powderEffect = saturate(powderEffect * 2.0);
                return lerp(1.0, lerp(1.0, powderEffect, smoothstep(0.5, -0.5, cosAngle)), intensity);
            }
            
            real4 FRAG(v2f i) : SV_TARGET
            {
                
                //float3  CameraPos    = _WorldSpaceCameraPos.xyz;
              
                float3  MinBox       = TransformWorldToObject(_MinBox);
                float3  MaxBox       = TransformWorldToObject(_MaxBox);
                
                float3  rayDirection = normalize(i.positionOS - i.CameraPosOS);
                float2  rayBoxDst    = RayBoxDst(MinBox,MaxBox,i.CameraPosOS,rayDirection);
                
                float   StepSize     = rayBoxDst.y / _NumSteps;
               
                float3  rayOrigin    = i.CameraPosOS + rayBoxDst.x * rayDirection;
                
                
                Light   mainLight    =   GetMainLight();
                float3  LightDirection = normalize(TransformWorldToObjectDir(mainLight.direction));
                float3  lightColor   =   mainLight.color;
                
                float   totalDistance=   rayBoxDst.y;
                float   currentDistance = 0;
                
                EnvironmentLighting environmentLighting;
                environmentLighting.sunDirection = LightDirection.xyz;
                environmentLighting.sunColor0 = lightColor.rgb;
                environmentLighting.sunColor1 = environmentLighting.sunColor0;
                environmentLighting.ambientTermTop = SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, half3(0.0, 1.0, 0.0), 5.0).rgb * _AmbientLightingTint;
                environmentLighting.ambientTermBottom = _GlossyEnvironmentColor.xyz;
                environmentLighting.cosAngle = dot(rayDirection, environmentLighting.sunDirection); 
                environmentLighting.cloudPMPC = SetupParticipatingMediaPhaseContextTest(environmentLighting.cosAngle, _PhaseG0, _PhaseG1, _PhaseBlendWeight, _MsPhaseFactor) ;
                
                float4 cloudResult;
                cloudResult.rgb = 0;
                cloudResult.a   = 1;
                
               
                float3 samplePos = 0;
                [unroll(64)]
                for(int StepIndex = 0;StepIndex < 64;StepIndex++)
                {
                     samplePos      = rayOrigin + _Offset;
                    
                    float  sampledDensity = SAMPLE_TEXTURE3D(_VolumeTex, sampler_LinearClamp, samplePos).r * _DensityScale;
                    UNITY_UNROLL
                    
                        
                        
                    if(sampledDensity >0.001f)
                    {
                        
                        float sampledSigmaT           =  sampledDensity ;
                        float normalizedHeight        =  (samplePos.y-MinBox.y) / (MaxBox.y - MinBox.y) ;
                        
                        float inscattering_probality  =  PowderEffect(sampledDensity,environmentLighting.cosAngle,1);
                        
                        ParticipatingMediaContext PMC =  SetupParticipatingMediaContext(_Albedo, sampledSigmaT, _MsScattFactor, _MsExtinFactor, 1.0f);
                        
                        float3 lightSamplePos         =  samplePos;
                        
                        EvaluateVolumetricShadow(lightSamplePos, LightDirection, PMC,MinBox,MaxBox);
                       
                        EvaluateLuminance(environmentLighting, PMC,normalizedHeight,inscattering_probality, StepSize, 0.5, cloudResult);
                        
                    }
                    rayOrigin += rayDirection * StepSize;
                    if(IsOutOfBound(rayOrigin,MinBox,MaxBox))
                        break;
                }
                
                
                return  cloudResult;
            }
            ENDHLSL
        }
//        Pass
//        {
//            Tags
//            {
//                "LightMode" = "DepthOnly"
//            }
//            Cull  Off
//            ZTest LEqual
//            ZWrite ON
//            
//            HLSLPROGRAM
//            #pragma vertex VERT
//            #pragma target 2.0
//            #pragma fragment FRAG
//            v2f VERT(a2v input)
//            {
//                v2f output;
//                UNITY_SETUP_INSTANCE_ID(input);
//                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
//                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
//                output.CameraPosOS= TransformWorldToObject(_WorldSpaceCameraPos);
//                output.texcoord.xy = input.texcoord;
//                output.positionOS = input.positionOS.xyz;
//                return output;
//            }
//            real4 FRAG(v2f i) : SV_TARGET
//            {
//                return i.positionCS.z;
//            }
//            ENDHLSL
//        }
            
    }
}