// This code was heavily based on this tutorial from catlikecoding.com by Jasper Flick: 
// https://catlikecoding.com/unity/tutorials/flow/waves/

Shader "Custom/Artnas/Water" {
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_BlendColor("Blend Color", Color) = (1,1,1,1)
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Amplitude("Amplitude", Float) = 1
		_Wavelength("Wavelength", Float) = 10
		_Speed("Speed", Float) = 1
		_InvFade("Soft Factor", Range(0.01,3.0)) = 1.0
		_FadeLimit("Fade Limit", Range(0.00,1.0)) = 0.3
	}
		SubShader{
			Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }
			LOD 200
			ZWRITE On

			CGPROGRAM
			#pragma surface surf Standard vertex:vert alpha:fade nolightmap
			#pragma target 3.0
			#include "UnityCG.cginc"

			sampler2D _MainTex;

			struct Input {
				float2 uv_MainTex;
				float4 screenPos;
				float eyeDepth;
			};

			fixed4 _Color;
			fixed4 _BlendColor;
			float _Amplitude;
			float _Wavelength;
			float _Speed;

			sampler2D_float _CameraDepthTexture;
			float4 _CameraDepthTexture_TexelSize;

			float _FadeLimit;
			float _InvFade;

			void vert(inout appdata_full v, out Input o) {
				UNITY_INITIALIZE_OUTPUT(Input, o);

				float3 p = v.vertex.xyz;

				float k = 2 * UNITY_PI / _Wavelength;
				float f1 = k * (p.x - _Speed * _Time.y);
				float f2 = k * (p.z - _Speed * _Time.x + 0.5);
				p.y = _Amplitude * sin(f1) * cos(f2);

				p.x += -_SinTime.w / 5;
				p.z += -_CosTime.w / 5;

				COMPUTE_EYEDEPTH(o.eyeDepth);

				v.vertex.xyz = p;
			}

			void surf(Input IN, inout SurfaceOutputStandard o) {
				half2 uvOffset = half2(-_SinTime.w / 10, -_CosTime.w / 10);
				fixed4 c = tex2D(_MainTex, IN.uv_MainTex + uvOffset) * _Color;

				o.Albedo = c.rgb;

				float rawZ = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos));
				float sceneZ = LinearEyeDepth(rawZ);
				float partZ = IN.eyeDepth;
				
				float fade = 1.0;
				if (rawZ > 0.0){
					fade = saturate(_InvFade * (sceneZ - partZ));
				}

				half3 blendColor = _BlendColor.rgb;
				if (fade < 0.15) {
					fade = 0;
					blendColor = half3(1, 1, 1);
				}

				o.Alpha = c.a;
				if (fade < _FadeLimit){
					o.Albedo = c.rgb * fade + blendColor * (1 - fade);
				}
			}
			ENDCG
		}
			FallBack "Diffuse"
}