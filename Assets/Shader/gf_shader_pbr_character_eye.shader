Shader "gf_shader/pbr/character/eye" {
	Properties {
		_MainTex ("MainTex", 2D) = "white" {}
		_BaseColor ("Main Color", Vector) = (1,1,1,1)
		_ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.25
		_Specularmap ("Specular Map", 2D) = "black" {}
		_SpecularIntensity ("Specular Intensity", Range(0, 3)) = 1.5
		_CorneaParallax ("Cornea Parallax", Range(0, 0.5)) = 0.3
		_SpecularParallax ("Specular Parallax", Range(0, 1)) = 0.3
		_ShadowBiasDistance ("Shadow Bias Distance", Range(0, 1)) = 0.1
		[HideInInspector] _QueueOffset ("Queue offset", Float) = 1
		[HideInInspector] _StencilRefE ("_StencilRefE", Float) = 204
		[HideInInspector] _FinalTint ("Final Tint", Vector) = (1,1,1,1)
		[HideInInspector] _HolographicColor ("Holographic Color", Vector) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
		[HideInInspector] _CharSaturation ("Char Saturation", Range(0, 1)) = 0
	}
	//DummyShaderTextExporter
	SubShader{
		Tags { "RenderType"="Opaque" }
		LOD 200
		CGPROGRAM
#pragma surface surf Standard
#pragma target 3.0

		sampler2D _MainTex;
		struct Input
		{
			float2 uv_MainTex;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
		}
		ENDCG
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
}