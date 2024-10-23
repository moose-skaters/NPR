// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X
Shader "Personal/Atmospherics/Height_Fog_Global"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _FogColor("FogColor",color) = (1,1,1,1)
        _FogIntensity("FogIntensity",float) = 1
        _FogHigh("FogHigh",float) = 1
    }
    SubShader
    {
        Tags {  "RenderPipeline"="UniversalPipeline"}
       

        Pass
        {
            //Tags{"LightMode"="UniversalForward"}
            ZTest Always
            ZWrite Off
            //Cull Off

            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"
            #include "FogCommon.hlsl"
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float4 ssTexcoord : TEXCOORD1;
               float3  worldPos    : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            float4 _MainTex_ST;
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            
             // DepthHeightFog Effect
           

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                o.ssTexcoord = TransformObjectToHClip(v.positionOS);
                o.worldPos   = v.positionOS;
                return o;
            }
            half _FogHeight;
            float4 frag (v2f i) : SV_Target
            {
               
               
                float2 UV = i.positionCS.xy / _ScaledScreenParams.xy;

                // Sample the depth from the Camera depth texture.
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                float3 postionWS = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                float4 MainColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,UV);
                float4 HeightFog = GetExponentialHeightFog(postionWS - _WorldSpaceCameraPos); 
                float4 finalResult = float4(MainColor.rgb*HeightFog.a+HeightFog.rgb, MainColor.a);
                return finalResult;
            }
            ENDHLSL
        }
    }

}
