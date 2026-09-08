// =============================================================================
// Shader Name: ArtFakeTesselation.fx
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

uniform bool EnableDebugMode <
    ui_label = "Debug (show mask)";
> = false;

uniform float SampleRadius <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 5.0; ui_step = 0.1;
    ui_label = "Shadow Radius (Blur)";
> = 1.0;

uniform float BumpStrength <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 8.0;
    ui_label = "Relief Strength (Density)";
> = 3.0;

uniform float NoiseThreshold <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.1; ui_step = 0.001;
    ui_label = "Noise treshold (Sensitivity)";
> = 0.005;

uniform float EffectIntensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Bump effect intensity";
> = 0.45;

uniform float ParallaxStrength <
    ui_type = "slider";
    ui_min = -0.02; ui_max = 0.02; ui_step = 0.001;
    ui_label = "Parallax Strength (Shift)";
> = 0.005;

uniform float HeightCutoff <
    ui_type = "slider";
    ui_min = 0.5; ui_max = 1.0; ui_step = 0.01;
    ui_label = "White clipping";
> = 1.0;

uniform float SharpenIntensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.1;
    ui_label = "Sharpness Compensation (Softness)";
> = 0.5;

texture TexOriginal { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler samplerOriginal { Texture = TexOriginal; };

texture TexBumped { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler samplerBumped { Texture = TexBumped; };

float GetLuma(sampler2D src, float2 texcoord)
{
    float3 color = tex2Dlod(src, float4(texcoord, 0.0, 0.0)).rgb;
    return dot(color, float3(0.299, 0.587, 0.114));
}

float4 PS_SaveFrame(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2D(ReShade::BackBuffer, texcoord);
}

float4 PS_ApplyBumpPro(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 base = tex2Dlod(samplerOriginal, float4(texcoord, 0.0, 0.0)).rgb;

    float2 offset = ReShade::PixelSize * SampleRadius;

    float left  = GetLuma(samplerOriginal, texcoord + float2(-offset.x, 0.0));
    float right = GetLuma(samplerOriginal, texcoord + float2(offset.x,  0.0));
    float up    = GetLuma(samplerOriginal, texcoord + float2(0.0, -offset.y));
    float down  = GetLuma(samplerOriginal, texcoord + float2(0.0,  offset.y));

    float gradientX = right - left;
    float gradientY = down - up;

    float edgeAmount = length(float2(gradientX, gradientY));
    edgeAmount = max(edgeAmount - NoiseThreshold, 0.0);
    edgeAmount *= BumpStrength;

    float blendFactor = 0.5 - clamp(edgeAmount, 0.0, 0.5);
    blendFactor = lerp(0.5, blendFactor, EffectIntensity);

    float3 finalColor;
    finalColor.r = (blendFactor < 0.5) ? (2.0 * base.r * blendFactor + base.r * base.r * (1.0 - 2.0 * blendFactor)) : (sqrt(base.r) * (2.0 * blendFactor - 1.0) + 2.0 * base.r * (1.0 - blendFactor));
    finalColor.g = (blendFactor < 0.5) ? (2.0 * base.g * blendFactor + base.g * base.g * (1.0 - 2.0 * blendFactor)) : (sqrt(base.g) * (2.0 * blendFactor - 1.0) + 2.0 * base.g * (1.0 - blendFactor));
    finalColor.b = (blendFactor < 0.5) ? (2.0 * base.b * blendFactor + base.b * base.b * (1.0 - 2.0 * blendFactor)) : (sqrt(base.b) * (2.0 * blendFactor - 1.0) + 2.0 * base.b * (1.0 - blendFactor));

    return float4(clamp(finalColor, 0.0, 1.0), 1.0);
}

float4 PS_ApplyParallaxAndSharpen(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2Dlod(samplerBumped, float4(texcoord, 0.0, 0.0)).rgb;
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    
    float height = saturate(luma * 4.0);
    height = pow(height, 2.0);
    
    if (height > HeightCutoff) height = 0.0;

    if (EnableDebugMode)
    {
        return float4(height.xxx, 1.0);
    }

    float2 viewDir = texcoord - 0.5;
    float2 parallaxOffset = viewDir * height * ParallaxStrength;
    float2 finalTexCoords = texcoord + parallaxOffset;
    finalTexCoords = clamp(finalTexCoords, 0.0, 1.0);

    float3 centerColor = tex2Dlod(samplerBumped, float4(finalTexCoords, 0.0, 0.0)).rgb;

    float2 blurOffset = ReShade::PixelSize;
    float3 blurColor = tex2Dlod(samplerBumped, float4(finalTexCoords + float2(-blurOffset.x, 0.0), 0.0, 0.0)).rgb;
    blurColor += tex2Dlod(samplerBumped, float4(finalTexCoords + float2(blurOffset.x, 0.0), 0.0, 0.0)).rgb;
    blurColor += tex2Dlod(samplerBumped, float4(finalTexCoords + float2(0.0, -blurOffset.y), 0.0, 0.0)).rgb;
    blurColor += tex2Dlod(samplerBumped, float4(finalTexCoords + float2(0.0, blurOffset.y), 0.0, 0.0)).rgb;
    blurColor /= 4.0;

    float3 finalColor = centerColor + (centerColor - blurColor) * SharpenIntensity;
    return float4(clamp(finalColor, 0.0, 1.0), 1.0);
}

technique ArtFakeTesselation
<
    ui_label = "ArtFakeTesselation";
    ui_tooltip = "Screen-Space 3D Relief & Offset Parallax";
>
{
    pass Pass1
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SaveFrame;
        RenderTarget = TexOriginal;
    }
    pass Pass2
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ApplyBumpPro;
        RenderTarget = TexBumped;
    }
    pass Pass3
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ApplyParallaxAndSharpen;
    }
}