#[compute]
#version 450
#extension GL_EXT_samplerless_texture_functions : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 注意：这里是 texture2D，不是 sampler2D！
layout(set = 0, binding = 0) uniform texture2D left_tex;
layout(set = 0, binding = 1) uniform texture2D right_tex;

layout(set = 0, binding = 2, rgba8) writeonly uniform image2D output_img;


struct CameraParameter {
    float rotate_x;   
    float rotate_y;   
    float rotate_z;   
    float width;     
    float height;     

    float fx;         
    float fy;         
    float cx;         
    float cy;         
};

// Uniform Buffer - 与 C# 结构体完全匹配
layout(std140, set = 0, binding = 3) uniform ConfigUBO
{
    CameraParameter left_camera;
    CameraParameter right_camera;
}configData;

const float PI = 3.14159265359;

float DegToRad(float deg) {
    return deg * PI / 180.0;
}

float RadToDeg(float rad)
{
    return rad * 180.0 / PI;
    
}

vec4 GetColor1(int pictureIndex, int x, int y)
{
    ivec2 coord = ivec2(x, y);
    if(pictureIndex == 0)
    {
        return texelFetch(left_tex, coord, 0); 
    }
    else
    {
        return texelFetch(right_tex, coord, 0); 
    }
}


vec2 ComputeUV2(
    float horizontal_angle_deg, 
    float vertical_angle_deg,
    float fx,
    float fy,
    float cx,
    float cy,
    vec4 position,
    vec4 rotation,
    float width,
    float height)
{
    //先求水平的角度

    //水平fov 
    float h_fov = RadToDeg(atan(width / (2 * fx)));

    float h_deg = horizontal_angle_deg - rotation.y;
    if (h_deg < -h_fov || h_deg > h_fov) { return vec2(-1, -1); }

    float hRad = DegToRad(h_deg);
    float u = tan(hRad)*fx;
    
    //垂直fov
    float v_fov = RadToDeg(atan(height / (2 * fy)));
    float v_deg = vertical_angle_deg - rotation.x;
    if(v_deg < -v_fov || v_deg > v_fov) { return vec2(-1, -1); }
    float vRad = DegToRad(v_deg);
    float v = tan(vRad) *fy;

    //旋转
    float rz = DegToRad(-rotation.z);
    float ru = u * cos(rz) - v * sin(rz);
    float rv = u * sin(rz) + v * cos(rz);

    //return vec2(ru + (width/2) + (width/2 - cx), rv + (height/2) + (height/2 - cy));
    return vec2(ru + cx, rv + (height/2) + (height/2 - cy));
}


vec2 ComputeUV(int x, int y, CameraParameter camParam, ivec2 outputSize, float h_outputDegree,
float v_outputDegree)
{
    float horizontalAngleRate = float(x) / outputSize.x - 0.5f;
    float horizontalAngle = horizontalAngleRate * h_outputDegree;

    float verticalAngleRate = float(y) / outputSize.y - 0.5f;
    float verticalAngle = verticalAngleRate * v_outputDegree;

    vec4 position = vec4(0);
    vec4 rotation = vec4(camParam.rotate_x, camParam.rotate_y, camParam.rotate_z, 0);

    return ComputeUV2(
        horizontalAngle,
        verticalAngle,
        camParam.fx,
        camParam.fy,
        camParam.cx,
        camParam.cy,
        position,
        rotation,
        camParam.width,
        camParam.height
    );
}




void main() 
{
    ivec2 outputSize = imageSize(output_img);
    ivec2 current_coord = ivec2(gl_GlobalInvocationID.xy);
    // 如果超出输出范围则返回
    if (current_coord.x >= outputSize.x || current_coord.y >= outputSize.y) {
        return;
    }

    float h_out = 97;
    float v_out = 28;

    bool hasColor0 = false;
    bool hasColor1 = false;


    vec4 color0 = vec4(0);
    vec2 uv0 = ComputeUV(current_coord.x, current_coord.y, configData.left_camera, outputSize, h_out, v_out);
    if(uv0.x >= 0.0 && uv0.y >= 0.0 && uv0.x < 1920 && uv0.y < 1080)
    {
        int ix = int(uv0.x);
        int iy = int(uv0.y);
        color0 = GetColor1(0, ix, iy);
        hasColor0 = true;
    }

    vec4 color1 = vec4(0);
    vec2 uv1 = ComputeUV(current_coord.x, current_coord.y, configData.right_camera, outputSize, h_out, v_out);
    if(uv1.x >= 0.0 && uv1.y >= 0.0 && uv1.x < 1920 && uv1.y < 1080)
    {
        int ix = int(uv1.x);
        int iy = int(uv1.y);
        color1 = GetColor1(1, ix, iy);
        hasColor1 = true;
    }

    vec4 rgba = vec4(0.0);
    if(hasColor0 && !hasColor1)
    {
        rgba = color0;
    }
    else if(hasColor0 && hasColor1)
    {
        rgba = mix(color0, color1, 0.5);
    }
    else if(hasColor1)
    {
        rgba = color1;
    }

    imageStore(output_img, current_coord, rgba);

}