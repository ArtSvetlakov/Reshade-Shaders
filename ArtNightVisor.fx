// =============================================================================
// Shader Name: ArtNightVisor.fx
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
sampler2D samplerColor
{
    Texture = texColorBuffer;
};

uniform int ColorMode <
    ui_type = "combo";
    ui_label = "Color of Night Vision";
    ui_items = "Green\0Blue\0\0";
> = 0;

float4 PS_NightVisorShader(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 color = tex2D(samplerColor, uv);
    color.rgb = color.rgb * 2.5;
    if (ColorMode == 0) 
    {
        color.r = 0.0;
        color.b = 0.0;
    }
    else if (ColorMode == 1) 
    {
        color.r = 0.0;
        color.g = color.g * 0.75 + color.b * 0.2;
        color.b = color.b * 2.2;
    }
    return color;
};

technique NightVisorShader
<
    ui_label = "ArtNightVisor";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_NightVisorShader;
    }
};