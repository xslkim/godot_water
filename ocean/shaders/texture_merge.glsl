#[compute]
#version 450

#extension GL_EXT_samplerless_texture_functions : require

// 定义工作组大小
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 输入纹理：只读
layout(set = 0, binding = 0) uniform sampler2D left_tex;
layout(set = 0, binding = 1) uniform sampler2D right_tex;

// 输出纹理：可写
layout(set = 0, binding = 2, rgba8) writeonly uniform image2D output_img;

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_img);

    if (coord.x >= size.x || coord.y >= size.y) return;

    // 使用 texelFetch 从输入纹理读取数据
    vec4 left = texelFetch(left_tex, coord, 0);
    vec4 right = texelFetch(right_tex, coord, 0);

    // 示例：简单混合
    vec4 result = (left + right) * 0.5;

    // 将结果存储到输出图像
    imageStore(output_img, coord, result);
}