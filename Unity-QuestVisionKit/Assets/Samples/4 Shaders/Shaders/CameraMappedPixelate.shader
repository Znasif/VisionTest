// Dichoptic Camera Mapping Shader with Pixelation
// Left eye: pixelated camera feed
// Right eye: invisible/transparent
Shader "Custom/CameraMappedPixelate"
{
    Properties
    {
        _PixelSize ("Pixel Size", Range(0.001, 0.1)) = 0.05
        _TintColor ("Tint Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "Camera Mapped Dichoptic Pixelate"
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            // Enable all stereo rendering variants
            #pragma multi_compile_instancing
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;
            float _PixelSize;
            float4 _TintColor;

            // Controller-updated uniforms:
            float3 _CameraPos;
            float2 _FocalLength;       // In pixels.
            float2 _PrincipalPoint;    // In pixels (from top-left).
            float2 _IntrinsicResolution; // Calibration resolution.
            float4x4 _CameraRotationMatrix;

            struct Attributes 
            { 
                float4 vertex : POSITION; 
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 clipPos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                
                OUT.clipPos = TransformObjectToHClip(IN.vertex);
                float4 worldPos = mul(unity_ObjectToWorld, IN.vertex);
                OUT.worldPos = worldPos.xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                
                // --- Dichoptic Rendering Logic ---
                // Automatic VR eye detection
                int eyeIndex = 0;
                
                #ifdef UNITY_SINGLE_PASS_STEREO
                    eyeIndex = unity_StereoEyeIndex;
                #endif
                
                #ifdef STEREO_INSTANCING_ON
                    eyeIndex = unity_StereoEyeIndex;
                #endif
                
                #ifdef STEREO_MULTIVIEW_ON
                    eyeIndex = unity_StereoEyeIndex;
                #endif

                if (eyeIndex == 1) {
                    // Right Eye: Invisible/transparent
                    discard;
                    // Alternative: return half4(0, 0, 0, 0); for transparency
                }

                // Left Eye: Pixelated camera feed
                float3 diff = IN.worldPos - _CameraPos;
                float3 localPos = mul(_CameraRotationMatrix, float4(diff, 1.0)).xyz;
                if (localPos.z < 0.001)
                    discard;

                // Compute image-plane coordinates (in intrinsic sensor pixels)
                float uImage = _FocalLength.x * (localPos.x / localPos.z) + _PrincipalPoint.x;
                float vImage = _FocalLength.y * (localPos.y / localPos.z) + _PrincipalPoint.y;
                
                // Scale from intrinsic resolution to actual texture resolution.
                float scaleX = _MainTex_TexelSize.z / _IntrinsicResolution.x;
                float scaleY = _MainTex_TexelSize.w / _IntrinsicResolution.y;
                uImage *= scaleX;
                vImage *= scaleY;

                // Normalize to [0,1] UVs.
                float u = uImage / _MainTex_TexelSize.z;
                float v = vImage / _MainTex_TexelSize.w;
                float2 computedUV = float2(u, v);

                // Pixelate effect
                computedUV = floor((computedUV / _PixelSize).xy) * _PixelSize;
                
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, computedUV);
                
                // Apply tint color
                col.rgb *= _TintColor.rgb;
                col.a *= _TintColor.a;

                return col;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}