#[compute]
#version 450
#extension GL_EXT_samplerless_texture_functions : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 注意：这里是 texture2D，不是 sampler2D！
layout(set = 0, binding = 0) uniform texture2D left_tex;
layout(set = 0, binding = 1) uniform texture2D right_tex;

layout(set = 0, binding = 2, rgba8) writeonly uniform image2D output_img;

// Uniform Buffer - 与 C# 结构体完全匹配
layout(std140, set = 0, binding = 3) uniform ComputeUniforms
{
    float fov_x_uni;      // 0
    float rotate_x_uni;   // 4
    float rotate_y_uni;   // 8
    float rotate_z_uni;   // 12
    float width_uni;      // 16
    float height_uni;     // 20
    float fx_uni;         // 24
    float fy_uni;         // 28
    float cx_uni;         // 32
    float cy_uni;         // 36
    // 如果 C# 结构体有 padding，这里也要对应
    // vec2 padding;  // 40-48
};

const float PI = 3.14159265359;

float DegToRad(float deg) {
    return deg * PI / 180.0;
}

float RadToDeg(float rad)
{
    return rad * 180.0 / PI;
    
}

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_img);
    if (coord.x >= size.x || coord.y >= size.y) 
    {
        return;
    }

    // float h_degree = 52+45;
    // float h_rad = ((gl_GlobalInvocationID.x / float(size.x)) - 0.5)*h_degree;
    // float theta_h_rad = DegToRad(h_rad);

    // float v_degree = 28;
    // float v_rad = ((gl_GlobalInvocationID.y / float(size.y)) - 0.5)*v_degree;
    // float theta_v_rad = DegToRad(v_rad);

    float w = width_uni;
    float h = height_uni;
    float fov_x = radians(fov_x_uni);
    float fx = (w / 2.0) / tan(fov_x / 2.0); // 像素单位焦距
    float fy = fx; // 假设方形像素（Godot 默认）
    float cx = w / 2.0;
    float cy = h / 2.0;

    // R(+30°) 绕 Y 轴
    float angle = radians(rotate_y_uni);
    float c = cos(angle);
    float s = sin(angle);

    // 手动展开 H = K * R * K^{-1}，作用于齐次坐标 [x, y, 1]
    // 先应用 K^{-1}: (x - cx)/fx, (y - cy)/fy, 1
    vec2 p = coord;
    vec3 ray = vec3(
        (p.x - cx) / fx,
        (p.y - cy) / fy,
        1.0
    );

    // 应用 R(+30°)
    vec3 rotated = vec3(
        c * ray.x + s * ray.z,
        ray.y,
        -s * ray.x + c * ray.z
    );

    // 应用 K: x' = fx * X / Z + cx, etc.
    vec2 p_original;
    if (abs(rotated.z) < 1e-6) {
        imageStore(output_img, coord, vec4(0,1,1,1));
        return;
    }
    p_original.x = fx * rotated.x / rotated.z + cx;
    p_original.y = fy * rotated.y / rotated.z + cy;

    if( p_original.y < 0.0 || p_original.y >= h) {
        imageStore(output_img, coord, vec4(0,0,1,1));
        return;
    }

    if( p_original.x >= w ) {
        imageStore(output_img, coord, vec4(0,1,0,1));
        return;
    }

    if(p_original.x < 0.0  ) {
        imageStore(output_img, coord, vec4(1,0,0,1));
        return;
    }

    ivec2 p_original_ivec = ivec2(int(p_original.x), int(p_original.y));
    vec4 left = texelFetch(left_tex, p_original_ivec, 0);  
    //vec4 right = texelFetch(right_tex, coord, 0);

    vec4 result = left; //(left + right) * 0.5;
    imageStore(output_img, coord, result);
}