Shader "gf_shader/pbr/character/uber" {
	Properties {
		[Header(State)] [Toggle(_DOUBLE_SIDED)] _DoubleSided ("Double Sided", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _Cull ("Cull", Float) = 2
		[Toggle(_ALPHATEST_ON)] _UseAlphaTest ("Use Alpha Test", Float) = 0
		[HiddenByKeyword(_ALPHATEST_ON)] _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.15
		[HideInInspector] _OutlineOffset ("Outline Offset", Range(0, 20)) = 0
		[Header(Albedo)] _BaseColor ("Color", Vector) = (0.5,0.5,0.5,1)
		_BaseMap ("Albedo Map (RGBA)", 2D) = "white" {}
		_OutlineColor ("Outline Color", Vector) = (0.6,0.6,0.6,0.1)
		_OutlineShadowColor ("Outline Shadow Color", Vector) = (0.6,0.6,0.6,1)
		[Header(Normalmap)] [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
		[Header(Stocking)] [Toggle(_USE_STOCKING)] _UseStockingFalloff ("Use Stocking Falloff", Float) = 0
		[HiddenByKeyword(_USE_STOCKING)] _StockingCenterColor ("Stocking Center Color", Vector) = (1,1,1,1)
		[HiddenByKeyword(_USE_STOCKING)] _StockingFalloffColor ("Stocking Falloff Color", Vector) = (0.1,0,0,1)
		[HiddenByKeyword(_USE_STOCKING)] _StockingFalloffPower ("Stocking Falloff Power", Range(0.1, 5)) = 1
		[HiddenByKeyword(_USE_STOCKING)] _AnisotropicGXX ("Anisotropic GGX", Range(-1, 1)) = 0
		[Header(Decal)] [Toggle(_GF_USE_DECAL)] _UseDecal ("Use Decal", Float) = 0
		[HiddenByKeyword(_GF_USE_DECAL)] _DecalMap ("Decal Map (RGBA)", 2D) = "black" {}
		[HiddenByKeyword(_GF_USE_DECAL)] [Toggle(_DECAL_USE_DETAIL_MAP)] _UseDetailMap ("Use Detail Map", Float) = 0
		[HiddenByKeyword(_DECAL_USE_DETAIL_MAP)] _DetailMaskLevelLow ("Detail Mask Level Low", Range(0, 1)) = 0
		[HiddenByKeyword(_DECAL_USE_DETAIL_MAP)] _DetailMaskLevelHigh ("Detail Mask Level High", Range(0, 1)) = 1
		[Header(Roghness Metallic Occlusion)] _RMOTex ("RMO Map (RGB)", 2D) = "white" {}
		_EmissiveIntensity ("Emissive Intensity", Range(0, 10)) = 0
		[Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
		[HideInInspector] _StencilRefH ("_StencilRefH", Float) = 203
		[HideInInspector] _StencilRefE ("_StencilRefE", Float) = 204
		[HideInInspector] _StencilRefF ("_StencilRefF", Float) = 200
		[HideInInspector] _StencilRefC ("_StencilRefC", Float) = 206
		[HideInInspector] _WriteMask ("_WriteMask", Float) = 255
		[HideInInspector] _StencilRefCharStart ("_StencilRefCharStart", Float) = 200
		[HideInInspector] _DirOutlineWidthExt ("DirOutline Width Extend", Range(0, 0.3)) = 0
		[HideInInspector] _CampColorIndex ("Camp Color Index", Float) = 0
		[Toggle(_RAMPMAP)] _UseRampMap ("Use Ramp Map", Float) = 0
		[NoScaleOffset] _RampMap ("Diffuse Ramp Map", 2D) = "white" {}
		[Toggle(_GI_FLATTEN)] _UseGIFlatten ("Use GI Flatten", Float) = 0
		_OutlineWidth ("Outline width", Range(0, 10)) = 1
		_OutlineZBias ("Outline Z-Bias", Range(0, 1)) = 0
		_OutlineIntensity ("Outline Intensity", Range(1, 30)) = 1
		[Toggle(_ANISOTROPIC_SPECULAR)] _AnisotropicSpecular ("Use Anisotropic Specular", Float) = 0
		[Toggle(_SHADOW_ADDITIONAL_BIAS)] _AdjustShadowBias ("Adjust Shadow Bias", Float) = 0
		[HiddenByKeyword(_SHADOW_ADDITIONAL_BIAS)] _ShadowBiasDistance ("Shadow Bias Distance", Range(0, 1)) = 0.1
		_Anisotropy ("Anisotropy", Range(0, 5)) = 1
		_AnisotropyShift ("Anisotropy Shift", Range(0, 1)) = 0.05
		[Toggle(_BLEND_UV2)] _UseSpecularUV2 ("Use UV2", Float) = 0
		[Toggle(_USE_BLEND_TEX)] _UseBlendTex ("Use Blend Tex", Float) = 0
		_BlendTex ("Blend Tex", 2D) = "gray" {}
		_BlendSmoothness ("Blend Smoothness", Range(0, 1)) = 0.1
		[Toggle(_USE_FUR_SHELL)] _UseFurShell ("Use Fur Shell", Float) = 0
		[HiddenByKeyword(_USE_FUR_SHELL)] _FurShellThickness ("Fur Shell Thickness", Range(0.01, 5)) = 0.5
		[Toggle(_USE_VOLUMETRIC)] _UseVolumetricEffect ("Use Volumetric Effect", Float) = 0
		[HiddenByKeyword(_USE_VOLUMETRIC)] _BaseInsideLerp ("BaseInsideLerp", Range(-1, 1)) = 0
		[HiddenByKeyword(_USE_VOLUMETRIC)] [HDR] _InsideBaseColor ("InsideBaseColor", Vector) = (1,1,1,0)
		[HiddenByKeyword(_USE_VOLUMETRIC)] _InsideColorContrast ("InsideColorContrast", Range(0, 15)) = 1
		[HiddenByKeyword(_USE_VOLUMETRIC)] _InsideColorBias ("InsideColorBias", Range(-1, 1)) = 0.5
		[HiddenByKeyword(_USE_VOLUMETRIC)] _InsideHeightContrast ("InsideHeightContrast", Range(0, 2)) = 1
		[HiddenByKeyword(_USE_VOLUMETRIC)] _InsideHeightBias ("InsideHeightBias", Range(-1, 1)) = 0
		[HiddenByKeyword(_USE_VOLUMETRIC)] _FakeIntensity ("FakeIntersity", Range(0, 2)) = 0.25
		[HiddenByKeyword(_USE_VOLUMETRIC)] _ReflectionIntensity ("ReflectionIntensity", Range(0, 5)) = 0.35
		[HiddenByKeyword(_USE_VOLUMETRIC)] _ReflectionFresnelF0 ("ReflectionFresnelF0", Range(-1, 1)) = 0
		[Header(Character Effect)] [HideInInspector] _FinalTint ("Final Tint", Vector) = (1,1,1,1)
		[Toggle] [HideInInspector] _AoeSelect ("Aoe Select", Range(0, 1)) = 0
		[HideInInspector] _AoeSelectColor ("Aoe Select Color", Vector) = (1,1,1,1)
		[HideInInspector] _DissolveIntensity ("Dissolve Lerp", Range(0, 1)) = 0
		[HideInInspector] _EnableHolographicScanline ("_EnableHolographicScanline", Float) = 0
		[HideInInspector] _HolographicColor ("Holographic Color", Vector) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
		[HideInInspector] _Tutorial ("Tutorial", Range(0, 1)) = 0
		[HideInInspector] _TutorialColor ("Tutorial Color", Vector) = (1,1,1,1)
		[HideInInspector] _OnHitColor ("On Hit Color", Vector) = (0,0,0,1)
		[HideInInspector] _CharSaturation ("Char Saturation", Range(0, 1)) = 0
	}
	//DummyShaderTextExporter
	SubShader{
		Tags { "RenderType" = "Opaque" }
		LOD 200
		CGPROGRAM
#pragma surface surf Standard
#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			o.Albedo = 1;
		}
		ENDCG
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
	//CustomEditor "CharacterUberShaderGUI"
}