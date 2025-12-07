// Dichoptic Camera Mapping Shader with Regional Distortion
// Left eye: pincushion distortion in center, normal periphery
// Right eye: barrel distortion in center, normal periphery
Shader "Custom/CameraMappedDistortion"
{
    Properties
    {
        _TintColor ("Tint Color", Color) = (1, 1, 1, 1)
        _TunnelRadius ("Distortion Radius", Range(0.1, 1.0)) = 0.4
        _DistortionFeather ("Distortion Feather", Range(0.01, 0.5)) = 0.1
        _DistortionK1 ("Distortion K1", Range(-3.0, 3.0)) = 1.5
        _DistortionK2 ("Distortion K2", Range(-1.0, 1.0)) = 0.0
        _DistortionCenter ("Distortion Center", Vector) = (0.5, 0.5, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            // Enable all stereo rendering variants
            #pragma multi_compile_instancing
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // --- Shader Variables ---
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 _MainTex_TexelSize;
            float4 _TintColor;
            float _TunnelRadius;
            float _DistortionFeather;
            float _DistortionK1;
            float _DistortionK2;
            float2 _DistortionCenter;

            // --- Variables for Camera Mapping (set by C# script) ---
            float3 _CameraPos;
            float2 _FocalLength;
            float2 _PrincipalPoint;
            float2 _IntrinsicResolution;
            float4x4 _CameraRotationMatrix;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 worldPos     : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                
                return OUT;
            }

            // Function to apply barrel/pincushion distortion
            float2 applyDistortion(float2 source_uv, float k1, float k2)
            {
                // Calculate distance from distortion center
                float2 delta = source_uv - _DistortionCenter;
                float rr = sqrt(delta.x * delta.x + delta.y * delta.y);
                
                // Apply distortion formula (matching the original GLSL exactly)
                float r2 = rr * (1.0 + k1 * (rr * rr) + k2 * (rr * rr * rr * rr));
                float theta = atan2(delta.y, delta.x); // Note: y,x order for atan2
                
                // Calculate distorted coordinates
                float distortion_x = cos(theta) * r2; // cos for x component
                float distortion_y = sin(theta) * r2; // sin for y component
                
                return float2(distortion_x + _DistortionCenter.x, distortion_y + _DistortionCenter.y);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                
                // --- Camera Mapping UV Calculation ---
                float3 diff = IN.worldPos - _CameraPos;
                float3 localPos = mul(_CameraRotationMatrix, float4(diff, 1.0)).xyz;
                if (localPos.z < 0.001)
                    discard;

                float uImage = _FocalLength.x * (localPos.x / localPos.z) + _PrincipalPoint.x;
                float vImage = _FocalLength.y * (localPos.y / localPos.z) + _PrincipalPoint.y;
                
                float scaleX = _MainTex_TexelSize.z / _IntrinsicResolution.x;
                float scaleY = _MainTex_TexelSize.w / _IntrinsicResolution.y;
                uImage *= scaleX;
                vImage *= scaleY;

                float u = uImage / _MainTex_TexelSize.z;
                float v = vImage / _MainTex_TexelSize.w;
                float2 computedUV = float2(u, v);

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

                // Convert UV to centered coordinates for distance calculation
                float2 centeredUV = computedUV * 2.0 - 1.0;
                float distFromCenter = length(centeredUV);
                
                // Calculate blend factor (same for both eyes to ensure matching regions)
                float blendFactor = smoothstep(_TunnelRadius - _DistortionFeather, _TunnelRadius + _DistortionFeather, distFromCenter);
                
                // Sample original camera texture
                float3 originalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, computedUV).rgb;
                float3 distortedColor;
                
                if (eyeIndex == 0) {
                    // Left Eye: Pincushion distortion (negative K1) in center
                    float2 distortedUV = applyDistortion(computedUV, -abs(_DistortionK1), _DistortionK2);
                    distortedUV = clamp(distortedUV, 0.0, 1.0);
                    distortedColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, distortedUV).rgb;
                } else {
                    // Right Eye: Barrel distortion (positive K1) in center
                    float2 distortedUV = applyDistortion(computedUV, abs(_DistortionK1), _DistortionK2);
                    distortedUV = clamp(distortedUV, 0.0, 1.0);
                    distortedColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, distortedUV).rgb;
                }
                
                // Blend between distorted center and original periphery
                float3 finalColor = lerp(distortedColor, originalColor, blendFactor);
                
                // Apply tint color
                finalColor *= _TintColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}