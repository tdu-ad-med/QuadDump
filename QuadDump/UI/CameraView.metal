#include <metal_stdlib>
using namespace metal;

constant auto yCbCrToRGB = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                    float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                    float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                    float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));

struct RasterizerData
{
    float4 clipSpacePosition [[position]];
    float2 texCoord;
};

float4 colorful(float num)
{
	num = log(num);
	float fill = step(0.6, fract(num * 8.0));
	num = fract(num) * 6.0;
	float3 color =
		(              num < 1.0) ? float3(1.0      , num      , 0.0      ) :
		(1.0 <= num && num < 2.0) ? float3(2.0 - num, 1.0      , 0.0      ) :
		(2.0 <= num && num < 3.0) ? float3(0.0      , 1.0      , num - 2.0) :
		(3.0 <= num && num < 4.0) ? float3(0.0      , 4.0 - num, 1.0      ) :
		(4.0 <= num && num < 5.0) ? float3(num - 4.0, 0.0      , 1.0      ) :
		                            float3(1.0      , 0.0      , 6.0 - num);

	return float4(color, fill);
}

vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             const device float4 *position [[ buffer(0) ]],
             const device float2 *uv [[ buffer(1) ]])
{
    RasterizerData out;
    out.clipSpacePosition = position[vertexID];
    out.texCoord = uv[vertexID];
    return out;
}

fragment float4
fragmentShader(RasterizerData in [[ stage_in ]],
               texture2d<float, access::sample> colorTextureY [[ texture(0) ]],
               texture2d<float, access::sample> colorTextureCbCr [[ texture(1) ]],
               texture2d<float, access::sample> depthTexture [[texture(2)]])
{
    constexpr sampler sampler2d(mip_filter::linear, mag_filter::linear, min_filter::linear);
    const float4 ycbcr = float4(colorTextureY.sample(sampler2d, in.texCoord).r, colorTextureCbCr.sample(sampler2d, in.texCoord).rg, 1);
    const float3 color = (yCbCrToRGB * ycbcr).rgb;
    const float4 depth = colorful(depthTexture.sample(sampler2d, in.texCoord).r);
	const float3 result = color * 0.5 + depth.rgb * depth.a * 0.5;
    return float4(result, 1.0);
}
