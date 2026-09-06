// =============================================================================
// Shader Name: ArtOverbright.fx
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

uniform float Brightness <
    ui_type = "slider";
    ui_min = 1.0;
    ui_max = 3.0;
    ui_label = "Brightness";
> = 1.5;

uniform float Contrast <
    ui_type = "slider";
    ui_min = -1.0;
    ui_max = 1.0;
    ui_label = "Contrast / Tone Correction";
> = 0.3;

float4 PS_BrightShader(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 color = tex2D(samplerColor, uv);
    color.rgb = color.rgb * Brightness;
    float3 s_curve = sin(color.rgb * 3.14159265 - 1.57079632) * 0.5 + 0.5;
    color.rgb = lerp(color.rgb, s_curve, Contrast);
    return color;
};

technique BrightShader
<
    ui_label = "ArtOverbright";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BrightShader;
    }
};