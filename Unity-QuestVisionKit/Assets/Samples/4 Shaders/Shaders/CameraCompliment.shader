// Dichoptic Camera Mapping Shader with Complementary Blur Effects
// Left eye: center blurred, periphery clear
// Right eye: center clear, periphery blurred
Shader "Custom/CameraComplement"
{
    Properties
    {
        // _MainTex is controlled entirely by the C# script
        _TintColor ("Tint Color", Color) = (1, 1, 1, 1)
        _TunnelRadius ("Tunnel Radius", Range(0.1, 1.0)) = 0.3
        _BlurFeather ("Blur Feather", Range(0.01, 0.5)) = 0.1
        _BlurIntensity ("Blur Intensity", Range(1, 25)) = 10
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
            float _BlurFeather;
            float _BlurIntensity;

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

            // Function to apply Gaussian blur effect
            float3 applyBlur(float2 uv, float blurIntensity)
            {
                // Calculate kernel size based on blur intensity (odd number)
                int kernelSize = int(blurIntensity * 2.0 + 1.0);
                float sigma = blurIntensity;

                // Generate Gaussian kernel
                float kernel[26]; // Pre-allocate for max kernel size
                float kernelSum = 0.0;

                [loop]
                for (int i = 0; i < kernelSize; i++)
                {
                    float x = float(i) - float(kernelSize - 1) / 2.0;
                    kernel[i] = exp(-0.5 * (x * x) / (sigma * sigma));
                    kernelSum += kernel[i];
                }

                // Normalize kernel weights
                [loop]
                for (int j = 0; j < kernelSize; j++)
                {
                    kernel[j] /= kernelSum;
                }

                float2 texelSize = _MainTex_TexelSize.xy;
                float4 color = float4(0.0, 0.0, 0.0, 0.0);

                // Half size of the kernel for sampling offsets
                int halfKernel = kernelSize / 2;

                // Perform horizontal and vertical blur
                [loop]
                for (int y = -halfKernel; y <= halfKernel; y++)
                {
                    [loop]
                    for (int x = -halfKernel; x <= halfKernel; x++)
                    {
                        float weight = kernel[abs(x)] * kernel[abs(y)];
                        float2 offset = float2(x * texelSize.x, y * texelSize.y);
                        float2 sampleUV = uv + offset;
                        
                        // Clamp UV coordinates to prevent sampling outside texture bounds
                        sampleUV = clamp(sampleUV, 0.0, 1.0);

                        color += weight * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, sampleUV);
                    }
                }

                return color.rgb;
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

                // Convert UV to centered coordinates [-1, 1] for distance calculation
                float2 centeredUV = computedUV * 2.0 - 1.0;
                float distFromCenter = length(centeredUV);
                
                // Sample the original camera texture
                float3 originalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, computedUV).rgb;
                float3 blurredColor = applyBlur(computedUV, _BlurIntensity);
                
                // Calculate blend factor (same for both eyes to ensure matching regions)
                float blendFactor = smoothstep(_TunnelRadius - _BlurFeather, _TunnelRadius + _BlurFeather, distFromCenter);
                
                float3 finalColor;
                
                if (eyeIndex == 0) {
                    // Left Eye: Center blurred, periphery clear
                    // blendFactor = 0 at center (use blur), blendFactor = 1 at periphery (use original)
                    finalColor = lerp(blurredColor, originalColor, blendFactor);
                } else {
                    // Right Eye: Center clear, periphery blurred  
                    // blendFactor = 0 at center (use original), blendFactor = 1 at periphery (use blur)
                    finalColor = lerp(originalColor, blurredColor, blendFactor);
                }
                
                // Apply tint color only to final result, not affecting the blur calculation
                finalColor *= _TintColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}