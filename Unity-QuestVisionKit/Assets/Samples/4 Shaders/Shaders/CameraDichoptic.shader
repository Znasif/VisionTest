// Dichoptic Camera Mapping Shader with Aqua Effect
// Left eye: original camera feed, Right eye: aqua effect
Shader "Custom/CameraDichoptic"
{
    Properties
    {
        // _MainTex is controlled entirely by the C# script
        _NoiseTexture ("Noise Texture", 2D) = "gray" {}
        _TintColor ("Tint Color", Color) = (1, 1, 1, 1)
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _FillColor ("Fill Color", Color) = (1, 1, 1, 1)
        _Iteration ("Iterations", Range(1, 64)) = 16
        _EffectParams1 ("Effect Params 1 (-, Int, Blur, Freq)", Vector) = (0, 0.1, 0.5, 4)
        _EffectParams2 ("Effect Params 2 (Contrast, Hue)", Vector) = (2, 0.1, 0, 0)
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
            TEXTURE2D(_NoiseTexture);
            SAMPLER(sampler_NoiseTexture);

            float4 _MainTex_TexelSize;
            float4 _TintColor;
            float4 _EffectParams1;
            float2 _EffectParams2;
            float4 _EdgeColor;
            float4 _FillColor;
            uint _Iteration;

            // --- Variables for Camera Mapping (set by C# script) ---
            float3 _CameraPos;
            float2 _FocalLength;
            float2 _PrincipalPoint;
            float2 _IntrinsicResolution;
            float4x4 _CameraRotationMatrix;

            // --------------------------------------------------
            // Start of Embedded KinoAquaFilter.hlsl Code
            // --------------------------------------------------

            float Luminance(float3 c) { return dot(c, float3(0.2126729, 0.7151522, 0.0721750)); }
            float3 HsvToRgb(float3 c) {
                float3 rgb = clamp(abs(fmod(c.x * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
                return c.z * lerp(1.0, rgb, c.y);
            }

            struct KinoAquaFilter
            {
                float4 edgeColor;
                float4 fillColor;
                float aspectRatio, aspectRatioRcp;
                uint iteration;
                float iterationRcp;
                float interval, blurWidth, blurFrequency, edgeContrast, hueShift;

                float2 Rotate90(float2 v) { return v.yx * float2(-1, 1); }
                float2 UV2SC(float2 uv) { float2 p = uv - 0.5; p.x *= aspectRatio; return p; }
                float2 SC2UV(float2 p) { p.x *= aspectRatioRcp; return p + 0.5; }

                float3 SampleColor(float2 p) {
                    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, SC2UV(p)).rgb;
                }
                float SampleLuminance(float2 p) { return Luminance(SampleColor(p)); }
                float3 SampleNoise(float2 p) {
                    return SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, p).rgb;
                }

                float2 GetGradient(float2 p, float freq) {
                    const float2 dx = float2(interval / 200, 0);
                    float ldx = SampleLuminance(p + dx.xy) - SampleLuminance(p - dx.xy);
                    float ldy = SampleLuminance(p + dx.yx) - SampleLuminance(p - dx.yx);
                    float2 n = SampleNoise(p * 0.4 * freq).gb - 0.5;
                    return float2(ldx, ldy) + n * 0.05;
                }
                float ProcessEdge(inout float2 p, float stride) {
                    float2 grad = GetGradient(p, 1);
                    float edge = saturate(length(grad) * 10);
                    float pattern = SampleNoise(p * 0.8).r;
                    p += normalize(Rotate90(grad) + 1e-5) * stride;
                    return pattern * edge;
                }
                float3 ProcessFill(inout float2 p, float stride) {
                    float2 grad = GetGradient(p, blurFrequency);
                    p += normalize(grad + 1e-5) * stride;
                    float shift = SampleNoise(p * 0.1).r * 2;
                    return SampleColor(p) * HsvToRgb(float3(shift, hueShift, 1));
                }
                float3 ProcessAt(float2 uv) {
                    float2 p = UV2SC(uv);
                    float2 p_e_n = p, p_e_p = p, p_c_n = p, p_c_p = p;
                    const float Stride = 0.04 * iterationRcp;
                    float acc_e = 0, sum_e = 0, sum_c = 0;
                    float3 acc_c = 0;
                    
                    // Use [loop] to prevent forced unrolling on mobile platforms
                    [loop]
                    for (uint i = 0; i < iteration; i++) {
                        float w_e = 1.5 - i * iterationRcp;
                        acc_e += ProcessEdge(p_e_n, -Stride) * w_e;
                        acc_e += ProcessEdge(p_e_p, +Stride) * w_e;
                        sum_e += w_e * 2;
                        float w_c = 0.2 + i * iterationRcp;
                        acc_c += ProcessFill(p_c_n, -Stride * blurWidth) * w_c;
                        acc_c += ProcessFill(p_c_p, +Stride * blurWidth) * w_c * 0.3;
                        sum_c += w_c * 1.3;
                    }
                    acc_e /= sum_e;
                    acc_c /= sum_c;
                    acc_e = saturate((acc_e - 0.5) * edgeContrast + 0.5);
                    float3 rgb_e = lerp(1, edgeColor.rgb, edgeColor.a * acc_e);
                    float3 rgb_f = lerp(1, acc_c, fillColor.a) * fillColor.rgb;
                    return rgb_e * rgb_f;
                }
            };

            // --------------------------------------------------
            // End of Embedded KinoAquaFilter.hlsl Code
            // --------------------------------------------------

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
                
                float3 effectColor;
                
                if (eyeIndex == 0) {
                    // Left Eye: Original camera texture
                    effectColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, computedUV).rgb;
                } else {
                    // Right Eye: Apply aqua shader effect
                    KinoAquaFilter aqua;
                    aqua.edgeColor = _EdgeColor;
                    aqua.fillColor = _FillColor;
                    aqua.aspectRatio = _MainTex_TexelSize.z / _MainTex_TexelSize.w;
                    aqua.aspectRatioRcp = 1 / aqua.aspectRatio;
                    aqua.iteration = _Iteration;
                    aqua.iterationRcp = 1.0 / _Iteration;
                    aqua.interval = _EffectParams1.y;
                    aqua.blurWidth = _EffectParams1.z;
                    aqua.blurFrequency = _EffectParams1.w;
                    aqua.edgeContrast = _EffectParams2.x;
                    aqua.hueShift = _EffectParams2.y;

                    effectColor = aqua.ProcessAt(computedUV);
                }
                
                // Apply tint color
                float3 finalColor = effectColor * _TintColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}