Shader "Custom/InteriorMapping"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_CeilingTex("Ceiling (RGB)", 2D) = "white" {}
		_FloorTex("Floor (RGB)", 2D) = "white" {}
		_WallTex0("Wall 1 (RGB)", 2D) = "white" {}
		_WallTex1("Wall 2 (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Height ("Room Height", Float) = 1.0
		_Width ("Room Width", Float) = 1.0
		_Depth ("Room Depth", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

		#define RAY_ITERATIONS 1000
		#define RAY_MAGNITUDE 0.001

        sampler2D _MainTex;
		sampler2D _CeilingTex;
		float4 _CeilingTex_ST;
		sampler2D _FloorTex;
		float4 _FloorTex_ST;
		sampler2D _WallTex0;
		float4 _WallTex0_ST;
		sampler2D _WallTex1;
		float4 _WallTex1_ST;

        struct Input
        {
            float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		fixed _Height;
		fixed _Width;
		fixed _Depth;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here

        UNITY_INSTANCING_BUFFER_END(Props)

		// Plane functions
		fixed UpperPlaneDist(fixed y, fixed d)
		{
			return ceil(y / d) * d;
		}

		fixed LowerPlaneDist(fixed y, fixed d)
		{
			return (ceil(y / d) - 1) * d;
		}

		fixed4 interior(Input IN) {
			fixed4 c = fixed4(0.0f, 0.0f, 0.0f, 0.0f);

			// Get normal in object space.
			fixed3 pixelNormal = normalize(mul(unity_WorldToObject, IN.worldNormal));
			// Calculate object-space position of the pixel and
			// move the pixel position a little inwards the geometry, for preventing artifacts.
			fixed3 pixelPos = mul(unity_WorldToObject, IN.worldPos) - (pixelNormal * RAY_MAGNITUDE);
			// Get viewpoint from camera to pixel position.
			fixed3 direction = pixelPos - mul(unity_WorldToObject, _WorldSpaceCameraPos);

			// Calculate distances to inner planes.
			fixed ceilHeight = UpperPlaneDist(pixelPos.y, _Height);
			fixed floorHeight = LowerPlaneDist(pixelPos.y, _Height);
			fixed wall0 = UpperPlaneDist(pixelPos.x, _Width);
			fixed wall1 = LowerPlaneDist(pixelPos.x, _Width);
			fixed wall2 = UpperPlaneDist(pixelPos.z, _Depth);
			fixed wall3 = LowerPlaneDist(pixelPos.z, _Depth);

			// Raytrace intersection with inner planes.
			// Detect which materials are detected depending on the contact points.
			fixed3 norm = normalize(direction);
			fixed3 ray = pixelPos;
			int mat = 0;
			int i = 0;
			for (i = 0; i < RAY_ITERATIONS; i++) {
				ray = pixelPos + (i * norm * RAY_MAGNITUDE);

				if (ray.y >= ceilHeight) {
					mat = 0;
					break;
				}

				if (ray.y <= floorHeight) {
					mat = 1;
					break;
				}

				if (ray.x > wall0 || ray.x < wall1) {
					mat = 2;
					break;
				}

				if (ray.z > wall2 || ray.z < wall3) {
					mat = 3;
					break;
				}
			}

			// Map to proper texture.
			fixed deg = i / (RAY_ITERATIONS / 200.0f);
			switch (mat) {
			case 0:
				c = tex2D(_CeilingTex, TRANSFORM_TEX(ray.xz, _CeilingTex));
				break;
			case 1:
				c = tex2D(_FloorTex, TRANSFORM_TEX(ray.xz, _FloorTex));
				break;
			case 2:
				c = tex2D(_WallTex0, TRANSFORM_TEX(ray.zy, _WallTex0));
				break;
			case 3:
				c = tex2D(_WallTex1, TRANSFORM_TEX(ray.xy, _WallTex1));
				break;
			}

			return c;
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;

			//If the albedo color has an alpha value lower than 1, apply interior mapping
			if (c.a < 1.0f) {
				c = (c * c.a) + (interior(IN) * (1 - c.a));
			}
            // Albedo comes from a texture tinted by color
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
