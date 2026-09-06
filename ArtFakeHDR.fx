// =============================================================================
// Shader Name: ArtFakeHDR.fx
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
sampler2D samplerColor { Texture = texColorBuffer; };

uniform float TransferPower < 
    ui_type = "slider"; ui_min = 0.0; ui_max = 10.0; 
    ui_label = "Brightness of transmitted light"; 
> = 2.55;

uniform float ShadowDepth < 
    ui_type = "slider"; ui_min = 1.0; ui_max = 3.0; 
    ui_label = "Shadow density after fading"; 
> = 1.2;

float4 PS_UniversalLightPropagation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float TransferRange = 5.0;
	float LightThreshold = 1.0;
	float4 originalColor = tex2D(samplerColor, uv);
    float currentLuma = dot(originalColor.rgb, float3(0.2126, 0.7152, 0.0722));
    float3 transferredLight = float3(0.0, 0.0, 0.0);

    if (currentLuma < LightThreshold)
    {
        float distanceFactor = saturate(currentLuma / LightThreshold);
        float waveEnergy = pow(distanceFactor, 1.0 / TransferRange);
        float3 pureColorSpectrum = max(originalColor.rgb - currentLuma, 0.0);
        transferredLight = (originalColor.rgb + pureColorSpectrum) * waveEnergy * (1.0 - currentLuma) * TransferPower * 0.15;
    }

    float lightIntensity = saturate(transferredLight.r + transferredLight.g + transferredLight.b);
    originalColor.rgb += transferredLight;
    float3 shadowColor = pow(abs(originalColor.rgb), ShadowDepth);
    originalColor.rgb = lerp(shadowColor, originalColor.rgb, lightIntensity);
    originalColor.rgb = saturate(originalColor.rgb);
    return originalColor;
}

technique ArtSSLPF
<
    ui_label = "ArtFakeHDR";
    ui_tooltip = "Yet another fake HDR filter";
>
{
    pass 
    { 
        VertexShader = PostProcessVS; 
        PixelShader = PS_UniversalLightPropagation; 
    }
}
