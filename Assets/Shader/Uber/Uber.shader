Shader "Unlit/Uber"
{
    Properties
    {
        [Header(Base)]
        [KeywordEnum(Base,Skin,Face,Hair,Eye)] _ShaderEnum("Shader类型", int) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull (Default back)", Float) = 2
        
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength("OcclusionStrength",Range(0,1)) = 1
        _MetallicGlossMap("Metallic", 2D) = "black" {}
        _EmissionScale("_EmissionScale",Range(0,5)) = 0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Scale", Range(0,4)) = 1.0
        [Header(Hair)]
        _AnisotropyShift("AnisotropyShift",Range(0,0.1)) = 0.05
        _HairSpecularMap("HairSpecularMap",2D) = "white" {}
        _HairSpecularIntensity("HairSpecularIntensity",Range(0,2)) =   1
        _HairSpecularColorShadow("_HairSpecularColorShadow",Color) =   (1,1,1,1)
        _HairSpecularColorLight("_HairSpecularColorLight",  Color) =   (1,1,1,1)
        
        [Header(Stocking)]
        [Toggle]_Stocking("Stocking",Float) = 0.0
        _fresnelScale("fresnelScale", Range(0, 1)) = 1
		_fresnelIndensity("fresnelIndensity", Range(0, 5)) = 5
        _fresnelCenterColor("fresnelCenterColor",Color) = (1,1,1,1)
        _fresnelFallOffColor("fresnelCenterColor",Color) = (1,1,1,1)
        
        [Header(Ramp)]
        _RampTex("RampTex", 2D)    = "white" {}
        _RampMin("RampMin", Range(0,1)) = 0.0
        _RampMax("RampMax", Range(0,1)) = 1.0
        
        [Header(Outline)]
        _OutlineAdj01 ("描边距离范围x近处-y中间-z远距离",vector) = (0.01,2,6,0)
        _OutlineAdj02 ("描边范围缩放因子x近处-y中间-z远距离",vector) = (0.5, 0.74, 1.5, 0)
        _OutlineWidth ("描边粗细",float) = 0.56
        _OutlineScaleFactor ("描边缩放因子",float) = 0.00001
        _OutlineZOffset ("描边视角方向偏移",float) = 0
    }
    SubShader
    {
         
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}
       

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Cull [_Cull]
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            
            // -------------------------------------
            // Material Keywords
         
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
           
          
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _ _SKIN_ON
            #pragma shader_feature_local_fragment _ _HAIR_ON
            #pragma shader_feature_local_fragment _ _STOCKING_ON
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING
            #pragma shader_feature_local _SHADERENUM_BASE _SHADERENUM_SKIN _SHADERENUM_FACE _SHADERENUM_HAIR _SHADERENUM_EYE
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #define  _NORMALMAP 1
            #pragma multi_compile_fog
            

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON
        
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "UberInput.hlsl"
            #include "UberForwardPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "Outline"
            Tags{"LightMode" = "SRPDefaultUnlit"}
            Cull Front
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            // -------------------------------------
            // Universal Pipeline keywords
            // -------------------------------------
            // Unity defined keywords
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex   LitPassOutlineVertex
            #pragma fragment LitPassOutlineFragment

            #include "UberInput.hlsl"
            #include "UberLightingCore.hlsl"
            #include "UberForwardPassOutline.hlsl"
            ENDHLSL
        }
        
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
           

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "UberInput.hlsl"
            #include "UberShadowCasterPass.hlsl"
            ENDHLSL
        }

//        Pass
//        {
//            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
//            // no LightMode tag are also rendered by Universal Render Pipeline
//            Name "GBuffer"
//            Tags{"LightMode" = "UniversalGBuffer"}
//
//            ZWrite[_ZWrite]
//            ZTest LEqual
//            Cull[_Cull]
//
//            HLSLPROGRAM
//            #pragma exclude_renderers gles gles3 glcore
//            #pragma target 4.5
//
//            // -------------------------------------
//            // Material Keywords
//            #pragma shader_feature_local _NORMALMAP
//            #pragma shader_feature_local_fragment _ALPHATEST_ON
//            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
//            #pragma shader_feature_local_fragment _EMISSION
//            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
//            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//            #pragma shader_feature_local_fragment _OCCLUSIONMAP
//            #pragma shader_feature_local _PARALLAXMAP
//            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
//
//            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
//            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
//            #pragma shader_feature_local_fragment _SPECULAR_SETUP
//            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
//
//            // -------------------------------------
//            // Universal Pipeline keywords
//            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
//            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
//            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
//            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
//            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
//            #pragma multi_compile_fragment _ _SHADOWS_SOFT
//            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
//            #pragma multi_compile_fragment _ _LIGHT_LAYERS
//            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
//
//            // -------------------------------------
//            // Unity defined keywords
//            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
//            #pragma multi_compile _ SHADOWS_SHADOWMASK
//            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
//            #pragma multi_compile _ LIGHTMAP_ON
//            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
//            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
//
//            //--------------------------------------
//            // GPU Instancing
//            #pragma multi_compile_instancing
//            #pragma instancing_options renderinglayer
//            #pragma multi_compile _ DOTS_INSTANCING_ON
//
//            #pragma vertex LitGBufferPassVertex
//            #pragma fragment LitGBufferPassFragment
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
//            ENDHLSL
//        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
          

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "UberInput.hlsl"
            #include "UberDepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
          
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "UberInput.hlsl"
            #include "UberDepthOnlyNormal.hlsl"
            ENDHLSL
        }
    }
}
