// =============================================================================
// Shader Name: ArtTAV-GI.fx
// Author:      ArtSvetlakov / Artemiy Svetlakov
// Repository:  https://github.com/ArtSvetlakov/Reshade-Shaders
//
// LICENSE: Licensed under CC BY-NC-SA 4.0 (Creative Commons Non-Commercial)
//          https://creativecommons.org/licenses/by-nc-sa/4.0/
// STUCTLY FORBIDDEN to sell this shader, include it in paid mods/presets, 
//      or lock it behind paywalls (Patreon, Boosty, etc.). Redistribution 
//      in free mods is allowed only with proper credit to the author.
// =============================================================================


#include "ReShade.fxh"

texture2D texColorBuffer : COLOR;
sampler2D samplerColor { 
    Texture = texColorBuffer; 
    MipFilter = LINEAR; 
    MinFilter = LINEAR; 
    MagFilter = LINEAR; 
};

texture2D fLanternCoordsTexA { Width = 2; Height = 1; Format = RGBA16F; };
texture2D fLanternCoordsTexB { Width = 2; Height = 1; Format = RGBA16F; };

sampler2D samLanternCoordsA { Texture = fLanternCoordsTexA; };
sampler2D samLanternCoordsB { Texture = fLanternCoordsTexB; };

uniform float TransferPower < 
    ui_type = "slider"; ui_min = 0.0; ui_max = 10.0; 
    ui_label = "Brightness"; 
> = 2.5;

uniform float ShadowDepth < 
    ui_type = "slider"; ui_min = 1.0; ui_max = 3.0; 
    ui_label = "Shadow density after fading"; 
> = 1.1;

uniform float TrackingSmoothness < 
    ui_type = "slider"; ui_min = 0.85; ui_max = 0.99; ui_step = 0.005;
    ui_label = "Tracking smoothness (Flicker fix)"; 
> = 0.99;

float4 DynamicTrackingLogic(float2 uv, sampler2D oldCoordsSampler)
{
    float lod = 6.0; 
    
    float2 leftSum = 0.0;
    float leftWeight = 0.001;
    
    float2 rightSum = 0.0;
    float rightWeight = 0.001;

    [unroll]
    for (int x = 0; x < 8; x++)
    {
        [unroll]
        for (int y = 0; y < 8; y++)
        {
            float2 sampleUV = float2((x + 0.5) / 8.0, (y + 0.5) / 8.0);
            float3 sampleColor = tex2Dlod(samplerColor, float4(sampleUV, 0.0, lod)).rgb;
            float luma = dot(sampleColor, float3(0.2126, 0.7152, 0.0722));
            
            float threshold = 0.6;
            float weight = max(luma - threshold, 0.0);
            weight = pow(weight, 2.0);

            if (sampleUV.x < 0.5)
            {
                leftSum += sampleUV * weight;
                leftWeight += weight;
            }
            else
            {
                rightSum += sampleUV * weight;
                rightWeight += weight;
            }
        }
    }

    float2 rawLeftLantern  = leftSum / leftWeight;
    float2 rawRightLantern = rightSum / rightWeight;

    if (leftWeight < 0.01)  rawLeftLantern  = float2(0.25, 0.5);
    if (rightWeight < 0.01) rawRightLantern = float2(0.75, 0.5);

    float4 oldCoords = tex2D(oldCoordsSampler, uv);
    float2 smoothLeft  = lerp(rawLeftLantern,  oldCoords.xy, TrackingSmoothness);
    float2 smoothRight = lerp(rawRightLantern, oldCoords.zw, TrackingSmoothness);
    
    return float4(smoothLeft, smoothRight);
}

void PS_LanternCoordsTrackerA(float4 pos : SV_Position, float2 uv : TEXCOORD, out float4 color : SV_Target)
{
    color = DynamicTrackingLogic(uv, samLanternCoordsB);
}

void PS_LanternCoordsTrackerB(float4 pos : SV_Position, float2 uv : TEXCOORD, out float4 color : SV_Target)
{
    color = DynamicTrackingLogic(uv, samLanternCoordsA);
}

float4 PS_CombineGlow(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 originalColor = tex2D(samplerColor, uv);
    float currentLuma = dot(originalColor.rgb, float3(0.2126, 0.7152, 0.0722));
    float TransferRange = 5.0;
    float3 transferredLight = float3(0.0, 0.0, 0.0);
	float LightThreshold = 1.0;
    
    float4 stableCoords = tex2D(samLanternCoordsA, float2(0.5, 0.5));
    float2 leftLanternUV  = stableCoords.xy;
    float2 rightLanternUV = stableCoords.zw;
    
    float2 toLeft  = uv - leftLanternUV;
    float2 toRight = uv - rightLanternUV;
    toLeft.x  *= BUFFER_ASPECT_RATIO;
    toRight.x *= BUFFER_ASPECT_RATIO;
    float distToLeft  = length(toLeft);
    float distToRight = length(toRight);

    if (currentLuma < LightThreshold)
    {
        float radiusModifier = max(TransferRange * 0.12, 0.01);
        float leftVignette  = exp(-(distToLeft * distToLeft) / (radiusModifier * radiusModifier));
        float rightVignette = exp(-(distToRight * distToRight) / (radiusModifier * radiusModifier));
        float totalVignetteFlow = saturate(leftVignette + rightVignette);
        float3 pureColorSpectrum = max(originalColor.rgb - currentLuma, 0.0);
        float3 lightSourceEnergy = originalColor.rgb + pureColorSpectrum;
        float3 lampGlowColor = float3(1.0, 1.0, 1.0) * lightSourceEnergy;
        transferredLight = lampGlowColor * totalVignetteFlow * (1.0 - currentLuma) * TransferPower * 0.45;
    }

    float lightIntensity = saturate(transferredLight.r + transferredLight.g + transferredLight.b);
    originalColor.rgb += transferredLight;
    
    float3 shadowColor = pow(abs(originalColor.rgb), ShadowDepth);
    originalColor.rgb = lerp(shadowColor, originalColor.rgb, lightIntensity);

    originalColor.rgb = saturate(originalColor.rgb);
    return originalColor;
}

technique ArtTAVGI
<
    ui_label = "ArtTAV-GI";
    ui_tooltip = "Temporal Auto-Vignette Global Illumination";
>
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_LanternCoordsTrackerA; RenderTarget0 = fLanternCoordsTexA; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_CombineGlow; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_LanternCoordsTrackerB; RenderTarget0 = fLanternCoordsTexB; }
}
