// The triplanar mapping code is based on GPU Gems 3 from this tutorial by Ben Golus: 
// https://medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a

// I added vertex color based texture interpolation for up to 5 textures
// Artur Nasiadko - https://github.com/artnas

Shader "Custom/Artnas/Terrain/VertexColorBlendTriplanarMapping"
{
	Properties
	{
		_DefaultTex("Default", 2D) = "black" {}
		_RedTex("Red", 2D) = "red" {}
		_GreenTex("Green", 2D) = "green" {}
		_BlueTex("Blue", 2D) = "blue" {}
		_AlphaTex("Alpha", 2D) = "white" {}
		_Channels("Channel count", Int) = 5
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 150

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			// flip UVs horizontally to correct for back side projection
			#define TRIPLANAR_CORRECT_PROJECTED_U

			// offset UVs to prevent obvious mirroring
			#define TRIPLANAR_UV_OFFSET

			struct appdata
			{
				float4 color : COLOR;
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 color : COLOR;
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				half3 worldNormal : TEXCOORD1;
			};

			float4 _DefaultTex_ST;

			sampler2D _DefaultTex;
			sampler2D _RedTex;
			sampler2D _GreenTex;
			sampler2D _BlueTex;
			sampler2D _AlphaTex;

			fixed4 _LightColor0;

			int _Channels;

			v2f vert(appdata v)
			{
				v2f o;
				o.color = v.color;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// calculate triplanar blend
				half3 triblend = saturate(pow(i.worldNormal, 4));
				triblend /= max(dot(triblend, half3(1,1,1)), 0.0001);

				// preview blend
				// return fixed4(triblend.xyz, 1);

				// calculate triplanar uvs
				// applying texture scale and offset values ala TRANSFORM_TEX macro
				float2 uvX = i.worldPos.zy * _DefaultTex_ST.xy + _DefaultTex_ST.zw;
				float2 uvY = i.worldPos.xz * _DefaultTex_ST.xy + _DefaultTex_ST.zw;
				float2 uvZ = i.worldPos.xy * _DefaultTex_ST.xy + _DefaultTex_ST.zw;

				// offset UVs to prevent obvious mirroring
			#if defined(TRIPLANAR_UV_OFFSET)
				uvY += 0.33;
				uvZ += 0.67;
			#endif

				// minor optimization of sign(). prevents return value of 0
				half3 axisSign = i.worldNormal < 0 ? -1 : 1;

				// flip UVs horizontally to correct for back side projection
			#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
				uvX.x *= axisSign.x;
				uvY.x *= axisSign.y;
				uvZ.x *= -axisSign.z;
			#endif

				// albedo textures
				half4 colX = tex2D(_DefaultTex, uvX);
				half4 colY = tex2D(_DefaultTex, uvY);
				half4 colZ = tex2D(_DefaultTex, uvZ);
				half4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;

				half4 mask = i.color;
				half3 c = col.rgb;

				if (_Channels >= 2) {
					// texture sampling for each direction (x, y, z)
					half4 color0_X = tex2D(_RedTex, uvX);
					half4 color0_Y = tex2D(_RedTex, uvY);
					half4 color0_Z = tex2D(_RedTex, uvZ);
					// multiplying sampled colors by their respective directions
					half4 color0 = color0_X * triblend.x + color0_Y * triblend.y + color0_Z * triblend.z;

					// calculating the output color using vertex colors
					c = lerp(c, color0.rgb, mask.r);
				}

				if (_Channels >= 3){
					half4 color1_X = tex2D(_GreenTex, uvX);
					half4 color1_Y = tex2D(_GreenTex, uvY);
					half4 color1_Z = tex2D(_GreenTex, uvZ);
					half4 color1 = color1_X * triblend.x + color1_Y * triblend.y + color1_Z * triblend.z;

					c = lerp(c, color1.rgb, mask.g);
				}

				if (_Channels >= 4){
					half4 color2_X = tex2D(_BlueTex, uvX);
					half4 color2_Y = tex2D(_BlueTex, uvY);
					half4 color2_Z = tex2D(_BlueTex, uvZ);
					half4 color2 = color2_X * triblend.x + color2_Y * triblend.y + color2_Z * triblend.z;

					c = lerp(c, color2.rgb, mask.b);
				}

				if (_Channels >= 5){
					half4 color3_X = tex2D(_AlphaTex, uvX);
					half4 color3_Y = tex2D(_AlphaTex, uvY);
					half4 color3_Z = tex2D(_AlphaTex, uvZ);
					half4 color3 = color3_X * triblend.x + color3_Y * triblend.y + color3_Z * triblend.z;

					c = lerp(c, color3.rgb, mask.a);
				}

				// preview world normals
				// return fixed4(worldNormal * 0.5 + 0.5, 1);

				half3 worldNormal = i.worldNormal;

				// calculate lighting
				half ndotl = saturate(dot(worldNormal, _WorldSpaceLightPos0.xyz));
				half3 ambient = ShadeSH9(half4(worldNormal, 1));
				half3 lighting = _LightColor0.rgb * ndotl + ambient;

				// preview directional lighting
				// return fixed4(ndotl.xxx, 1);

				return fixed4(c.rgb * lighting, 1);
			}
			ENDCG
		}

		// this pass is required for cooperation with depthmask from water shader

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			struct v2f {
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert( appdata_base v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag( v2f i ) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}