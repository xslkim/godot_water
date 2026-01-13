#[compute]
#version 450
#extension GL_EXT_samplerless_texture_functions : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 注意：这里是 texture2D，不是 sampler2D！
layout(set = 0, binding = 0) uniform texture2D left_tex;
layout(set = 0, binding = 1) uniform texture2D right_tex;

layout(set = 0, binding = 2, rgba8) writeonly uniform image2D output_img;

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_img);
    if (coord.x >= size.x || coord.y >= size.y) return;

    vec4 left = texelFetch(left_tex, coord, 0);  
    vec4 right = texelFetch(right_tex, coord, 0);

    vec4 result = (left + right) * 0.5;
    imageStore(output_img, coord, result);
}