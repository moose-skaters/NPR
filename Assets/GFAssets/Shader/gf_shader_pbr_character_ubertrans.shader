Shader "gf_shader/pbr/character/ubertrans" {
	Properties {
		[Header(Albedo)] _BaseColor ("Color", Vector) = (0.5,0.5,0.5,1)
		_BaseMap ("Albedo Map (RGBA)", 2D) = "white" {}
		[Toggle(_ALPHATEST_ON)] _UseAlphaTest ("Use Alpha Test", Float) = 0
		[HiddenByKeyword(_ALPHATEST_ON)] _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.15
		[Toggle(_PRE_MUL_ALPHA)] _PreMulAlpha ("Pre Mul Alpha", Float) = 0
		[HideInInspector] _BlendMode ("Blend Mode", Float) = 5
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
		[Header(Roghness Metallic Occlusion)] _RMOTex ("RMO Map (RGB)", 2D) = "white" {}
		_EmissiveIntensity ("Emissive Intensity", Range(0, 10)) = 0
		[HideInInspector] _StencilRefC ("_StencilRefC", Float) = 206
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
		_Anisotropy ("Anisotropy", Range(-1, 1)) = 0
		_AnisotropyShift ("Anisotropy Shift", Range(-1, 1)) = 0
		_HairDummyDirection ("_HairDummyDirection", Vector) = (0,0,0,0.15)
		_HairDummyPosition ("_HairDummyPosition", Vector) = (0,1,0,0.15)
		[Toggle(_USE_BLEND_TEX)] _UseBlendTex ("Use Blend Tex", Float) = 0
		_BlendTex ("Blend Tex", 2D) = "gray" {}
		_BlendSmoothness ("Blend Smoothness", Range(0, 1)) = 0.1
		[Toggle(_SPECULAR_UV2)] _UseSpecularUV2 ("Use UV2", Float) = 0
		[Header(Character Effect)] [HideInInspector] _FinalTint ("Final Tint", Vector) = (1,1,1,1)
		[Toggle] [HideInInspector] _AoeSelect ("Aoe Select", Range(0, 1)) = 0
		[HideInInspector] _AoeSelectColor ("Aoe Select Color", Vector) = (1,1,1,1)
		[HideInInspector] _DissolveIntensity ("Dissolve Lerp", Range(0, 1)) = 0
		[HideInInspector] _EnableHolographicScanline ("_EnableHolographicScanline", Float) = 0
		[HideInInspector] _HolographicColor ("Holographic Color", Vector) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
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