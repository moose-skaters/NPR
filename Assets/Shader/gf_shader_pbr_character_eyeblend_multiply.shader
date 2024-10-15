Shader "gf_shader/pbr/character/eyeblend_multiply" {
	Properties {
		_MainColor ("Main Color", Vector) = (1,1,1,0.85)
		_MainTex ("Mask", 2D) = "white" {}
		_SpecularIntensity ("Multiply Intensity", Range(0, 1)) = 1
		[Header(Character Effect)] [HideInInspector] _HolographicColor ("Holographic Color", Vector) = (1,1,1,1)
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