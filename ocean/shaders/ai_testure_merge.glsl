#[compute]
#version 450
#extension GL_EXT_samplerless_texture_functions : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


layout(set = 0, binding = 0) uniform texture2D left_tex;
layout(set = 0, binding = 1) uniform texture2D front_tex;
layout(set = 0, binding = 2) uniform texture2D right_tex;

layout(set = 0, binding = 3, rgba8) writeonly uniform image2D output_img;


struct CameraParameter {
    vec4 position;
    vec4 rotation; 
    float fx;         
    float fy;         
    float cx;         
    float cy; 
    float w;         
    float h; 
    float padding1;
    float padding2;
};


layout(std140, set = 0, binding = 4) uniform ConfigUBO
{
    CameraParameter left_camera;
    CameraParameter front_camera;
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
    else if(pictureIndex == 1)
    {
        return texelFetch(front_tex, coord, 0);
    }
    else if(pictureIndex == 2)
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
    vec4 rotation = vec4(camParam.rotation.x, camParam.rotation.y, camParam.rotation.z, 0);

    return ComputeUV2(
        horizontalAngle,
        verticalAngle,
        camParam.fx,
        camParam.fy,
        camParam.cx,
        camParam.cy,
        position,
        rotation,
        camParam.w,
        camParam.h
    );
}

float InterpolateRate(float x, CameraParameter cam_left, CameraParameter cam_right, vec2 outputSize, float h_outputDegree)
{
    float horizontalAngleRate = x / outputSize.x - 0.5f;
    float horizontalAngle = horizontalAngleRate * h_outputDegree;
    
    //camera left
    float left_deg = horizontalAngle - cam_left.rotation.y;
    float left_fov = RadToDeg(atan(cam_left.w / (2 * cam_left.fx)));
    float distance_left = left_fov - left_deg;


    //camera right
    float right_deg = horizontalAngle - cam_right.rotation.y;
    float right_fov = RadToDeg(atan(cam_right.w / (2 * cam_right.fx)));
    float distance_right = right_deg - (-right_fov);

    float rate = distance_left / (distance_left + distance_right);
    //return (1-smoothstep(rate)); //使用平滑步进
    return (1-rate);
}

float calculate_half_fov(float fx, float width) {
    float half_tan = width / (2.0 * fx);
    float fov_rad = atan(half_tan);
    float fov_deg = RadToDeg(fov_rad);
    
    return fov_deg;
}


void main() 
{
    ivec2 outputSize = imageSize(output_img);

    ivec2 current_coord = ivec2(gl_GlobalInvocationID.xy);
    // 如果超出输出范围则返回
    if (current_coord.x >= outputSize.x || current_coord.y >= outputSize.y) {
        return;
    }

    float h_out = 142;
    float v_out = 30.66f;

    bool hasColor0 = false;
    bool hasColor1 = false;
    bool hasColor2 = false;


    //vec4 color0 = vec4(0);
    vec2 uv0 = ComputeUV(current_coord.x, current_coord.y, configData.left_camera, outputSize, h_out, v_out);
    if(uv0.x >= 0.0 && uv0.y >= 0.0 && uv0.x < 1920 && uv0.y < 1080)
    {
        //int ix = int(uv0.x);
        //int iy = int(uv0.y);
        //color0 = GetColor1(0, ix, iy);
        hasColor0 = true;
    }

    //cam.rotate_y  = 0;
    //vec4 color1 = vec4(0);
    vec2 uv1 = ComputeUV(current_coord.x, current_coord.y, configData.front_camera, outputSize, h_out, v_out);
    if(uv1.x >= 0.0 && uv1.y >= 0.0 && uv1.x < 1920 && uv1.y < 1080)
    {
        //int ix = int(uv1.x);
        //int iy = int(uv1.y);
        //color1 = GetColor1(1, ix, iy);
        hasColor1 = true;
    }

    //vec4 color2 = vec4(0);
    vec2 uv2 = ComputeUV(current_coord.x, current_coord.y, configData.right_camera, outputSize, h_out, v_out);
    if(uv2.x >= 0.0 && uv2.y >= 0.0 && uv2.x < 1920 && uv2.y < 1080)
    {
        //int ix = int(uv2.x);
        //int iy = int(uv2.y);
        //color2 = GetColor1(2, ix, iy);
        hasColor2 = true;
    }

    vec4 rgba = vec4(0.0);
    if(hasColor0 && !hasColor1)
    {
        rgba = GetColor1(0, int(uv0.x), int(uv0.y));;
    }
    else if(hasColor0 && hasColor1)
    {

    }
    else if(hasColor1 && !hasColor2)
    {
        rgba = GetColor1(1, int(uv1.x), int(uv1.y));
    }
    else if(hasColor1 && hasColor2)
    {
        //float rate = InterpolateRate(float(current_coord.x), configData.front_camera, configData.right_camera, outputSize, h_out);

        float leftCamRotation = configData.front_camera.rotation.y;
        float leftFx = configData.front_camera.fx;
        float leftWidth = configData.front_camera.w;
        float left_cam_fov_border_angle = leftCamRotation + calculate_half_fov(leftFx, leftWidth);


        // float rightCamRotation = configData.right_camera.rotation.y;
        // float rightFx = configData.right_camera.fx;
        // float rightWidth = configData.right_camera.w;
        //float right_cam_fov_border_angle = rightCamRotation - calculate_half_fov(rightFx, rightWidth);

        int left_border_x = int(outputSize.x * (left_cam_fov_border_angle+(h_out/2)/h_out));
        vec2 left_border_uv = ComputeUV(left_border_x, current_coord.y, configData.front_camera, outputSize, h_out, v_out);
        
        vec4 color_left = GetColor1(1, int(uv1.x), int(uv1.y));
        vec4 color_right = GetColor1(2, int(uv2.x), int(uv2.y));
        rgba = mix(color_left, color_right, 0.5);
        
    }
    else if(hasColor2)
    {
        rgba = GetColor1(2, int(uv2.x), int(uv2.y));
    }
    

    imageStore(output_img, current_coord, rgba);

}