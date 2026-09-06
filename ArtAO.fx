// =============================================================================
// Shader Name: ArtAO.fx
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
texture2D texDepthBuffer : DEPTH;

sampler2D samplerColor
{
    Texture = texColorBuffer;
};

sampler2D samplerDepth
{
    Texture = texDepthBuffer;
};

uniform float RayLength <
    ui_type = "slider";
    ui_min = 0.01; ui_max = 0.5;
    ui_label = "Ray Length";
> = 0.1;

uniform float DepthBias <
    ui_type = "slider";
    ui_min = 0.0001; ui_max = 0.01;
    ui_step = 0.0001;
    ui_label = "Ray offset";
> = 0.001;

uniform float MaxThickness <
    ui_type = "slider";
    ui_min = 0.001; ui_max = 0.2;
    ui_label = "Object's thickness";
> = 0.05;


float GetNoise(float2 co)
{
    return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453);
}

float4 PS_SimpleRT_Shader(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 color = tex2D(samplerColor, uv);
    float startDepth = ReShade::GetLinearizedDepth(uv);
    float totalAO = 0.0;
    
    int numRays = 8;
    int numSteps = 4;

    for (int r = 0; r < numRays; r++)
    {
        float angle = (float(r) / float(numRays)) * 6.283185;
        float2 rayDir = float2(cos(angle), sin(angle)) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

        for (int s = 1; s <= numSteps; s++)
        {
            float2 sampleUV = uv + (rayDir * s * RayLength * 50.0);
            float sampleDepth = ReShade::GetLinearizedDepth(sampleUV);

            if (sampleDepth < (startDepth - DepthBias) && sampleDepth > (startDepth - MaxThickness))
            {
                totalAO += (1.0 - (float(s) / float(numSteps)));
                break;
            }
        }
    }

    float ao = 1.0 - saturate((totalAO / float(numRays)) * 0.5);
    color.rgb = color.rgb * ao;
    return color;
}

technique BrightShader
<
    ui_label = "ArtAO";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SimpleRT_Shader;
    }
};