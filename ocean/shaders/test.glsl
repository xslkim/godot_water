#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;


layout(std430, binding = 1) readonly buffer InputBuffer1 {
    uint data1[];
};

layout(std430, binding = 2) readonly buffer InputBuffer2 {
    uint data2[];
};


layout(rgba8, binding = 0) writeonly uniform image2D outputImage;


struct CameraParameter {
    vec4 position;
    vec4 rotation;
    float fx, fy, cx, cy, w, h;
};

layout(std140, binding = 3) uniform ConfigUBO {
    CameraParameter rgb_cam[5];
    CameraParameter inf_cam[3];
} configData;


layout(push_constant) uniform PushConstants {
    float infraredRate;
} pushConstants;


const ivec2 inputSize = ivec2(3840, 2160);

vec4 unpackRGBA(uint packed) {
    return vec4(
        float( packed        & 0xFF) / 255.0,
        float((packed >> 8)  & 0xFF) / 255.0,
        float((packed >> 16) & 0xFF) / 255.0,
        float((packed >> 24) & 0xFF) / 255.0
    );
}

uint GetColor1(int pictureIndex, int x, int y)
{
    if(pictureIndex == 0)
    {
        int index = (y + 1080) * inputSize.x + x;
        return data1[index];
    }
    else if(pictureIndex == 1)
    {
        int index = (y + 1080) * inputSize.x  + (x+1920);
        return data1[index];
    }
    else if(pictureIndex == 2)
    {
        int index = (y) * inputSize.x  + x;
        return data1[index];
    }
    else // pictureIndex == 3
    {
        int index = (y) * inputSize.x  + (x+1920);
        return data1[index];
    }
    
    return 0;
}

uint GetColor2(int pictureIndex, int x, int y)
{
    int inf_offset = 568;
    if(pictureIndex == 0)
    {
        int index = y * inputSize.x + x;
        return data2[index];
    }
    else if(pictureIndex == 1)
    {
        int index = (y+inf_offset) * inputSize.x  + (x+1920);
        return data2[index];
    }
    else if(pictureIndex == 2)
    {
        int index = (y+inf_offset) * inputSize.x  + (x+1920+640);
        return data2[index];
    }
    else if(pictureIndex == 3)
    {
        int index = (y+inf_offset) * inputSize.x  + (x+1920+640+640);
        return data2[index];
    }
    
    return 0;
}
const float PI = 3.14159265359;

float DegToRad(float deg) {
    return deg * PI / 180.0;
}

float RadToDeg(float rad)
{
    return rad * 180.0 / PI;
    
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
    
    float v_fov = RadToDeg(atan(height / (2 * fy)));
    float v_deg = vertical_angle_deg - rotation.x;
    if(v_deg < -v_fov || v_deg > v_fov) { return vec2(-1, -1); }
    float vRad = DegToRad(v_deg);
    float v = tan(vRad) *fy;

    float rz = DegToRad(-rotation.z);
    float ru = u * cos(rz) - v * sin(rz);
    float rv = u * sin(rz) + v * cos(rz);

    return vec2(ru + cx, rv + (height/2) + (height/2 - cy));
}

vec2 ComputeUV(int x, int y, CameraParameter camParam, ivec2 outputSize, float h_outputDegree,
float v_outputDegree)
{
    float horizontalAngleRate = float(x) / outputSize.x - 0.5f;
    float horizontalAngle = horizontalAngleRate * h_outputDegree;

    float verticalAngleRate = float(y) / outputSize.y - 0.5f;
    float verticalAngle = verticalAngleRate * v_outputDegree;



    return ComputeUV2(
        horizontalAngle,
        verticalAngle,
        camParam.fx,
        camParam.fy,
        camParam.cx,
        camParam.cy,
        camParam.position,
        camParam.rotation,
        camParam.w,
        camParam.h
    );
}

float smoothstep(float t){
    //"""三次平滑步进"""
    return t * t * (3 - 2 * t);
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

void main() {

    // 输出纹理尺寸
    ivec2 outputSize = imageSize(outputImage);
    ivec2 current_coord = ivec2(gl_GlobalInvocationID.xy);
    // 如果超出输出范围则返回
    if (current_coord.x >= outputSize.x || current_coord.y >= outputSize.y) {
        return;
    }

    float h_out = 230;
    float v_out = 28;
    
    bool hasColor0 = false;
    bool hasColor1 = false;
    bool hasColor2 = false;
    bool hasColor3 = false;
    bool hasColor4 = false;

    uint color0 = uint(0);
    vec2 uv0 = ComputeUV(current_coord.x, current_coord.y, configData.rgb_cam[0], outputSize, h_out, v_out);
    if(uv0.x >= 0.0 && uv0.y >= 0.0 && uv0.x < 1920 && uv0.y < 1080)
    {
        int ix = int(uv0.x);
        int iy = int(uv0.y);
        color0 = GetColor1(0, ix, iy);
        hasColor0 = true;
    }

    uint color1 = uint(0);
    vec2 uv1 = ComputeUV(current_coord.x, current_coord.y, configData.rgb_cam[1], outputSize, h_out, v_out);
    if(uv1.x >= 0.0 && uv1.y >= 0.0 && uv1.x < 1920 && uv1.y < 1080)
    {
        int ix = int(uv1.x);
        int iy = int(uv1.y);
        color1 = GetColor1(1, ix, iy);
        hasColor1 = true;
    }

    uint color2 = uint(0);
    vec2 uv2 = ComputeUV(current_coord.x, current_coord.y, configData.rgb_cam[2], outputSize, h_out, v_out);
    if(uv2.x >= 0.0 && uv2.y >= 0.0 && uv2.x < 1920 && uv2.y < 1080)
    {
        int ix = int(uv2.x);
        int iy = int(uv2.y);
        color2 = GetColor1(2, ix, iy);
        hasColor2 = true;
    }

    uint color3 = uint(0);
    vec2 uv3 = ComputeUV(current_coord.x, current_coord.y, configData.rgb_cam[3], outputSize, h_out, v_out);
    if(uv3.x >= 0.0 && uv3.y >= 0. && uv3.x < 1920 && uv3.y < 10800)
    {
        int ix = int(uv3.x);
        int iy = int(uv3.y);
        color3 = GetColor1(3, ix, iy);
        hasColor3 = true;
    }

    uint color4 = uint(0);
    vec2 uv4 = ComputeUV(current_coord.x, current_coord.y, configData.rgb_cam[4], outputSize, h_out, v_out);
    if(uv4.x >= 0.0 && uv4.y >= 0.0 && uv4.x < 1920 && uv4.y < 1080)
    {
        int ix = int(uv4.x);
        int iy = int(uv4.y);
        color4 = GetColor2(0, ix, iy);
        hasColor4 = true;
    }

    vec4 rgba = vec4(0.0);
    if(hasColor0 && !hasColor1)
    {
        rgba = unpackRGBA(color0);
    }
    else if(hasColor0 && hasColor1)
    {
        vec4 rgbaA = unpackRGBA(color0);
        vec4 rgbaB = unpackRGBA(color1);
        float rate = InterpolateRate(float(current_coord.x), configData.rgb_cam[0], configData.rgb_cam[1], outputSize, h_out);
        rgba = mix(rgbaA, rgbaB, rate);
    }
    else if(hasColor1 && !hasColor2)
    {
        rgba = unpackRGBA(color1);
    }
    else if(hasColor1 && hasColor2)
    {
        vec4 rgbaA = unpackRGBA(color1);
        vec4 rgbaB = unpackRGBA(color2);
        float rate = InterpolateRate(float(current_coord.x), configData.rgb_cam[1], configData.rgb_cam[2], outputSize, h_out);
        rgba = mix(rgbaA, rgbaB, rate);
    }
    else if(hasColor2 && !hasColor3)
    {
        rgba = unpackRGBA(color2);
    }
    else if(hasColor2 && hasColor3)
    {
        vec4 rgbaA = unpackRGBA(color2);
        vec4 rgbaB = unpackRGBA(color3);
        float rate = InterpolateRate(float(current_coord.x), configData.rgb_cam[2], configData.rgb_cam[3], outputSize, h_out);
        rgba = mix(rgbaA, rgbaB, rate);
    }
    else if(hasColor3 && !hasColor4)
    {
        rgba = unpackRGBA(color3);
    }
    else if(hasColor3 && hasColor4)
    {
        vec4 rgbaA = unpackRGBA(color3);
        vec4 rgbaB = unpackRGBA(color4);
        float rate = InterpolateRate(float(current_coord.x), configData.rgb_cam[3], configData.rgb_cam[4], outputSize, h_out);
        rgba = mix(rgbaA, rgbaB, rate);
    }
    else if(hasColor4)
    {
        rgba = unpackRGBA(color4);
    }



    float infraredRate = 0;
    bool hasInfraredColor0 = false;
    bool hasInfraredColor1 = false;
    bool hasInfraredColor2 = false;


    uint inf_color0 = uint(0);
    vec2 inf_uv0 = ComputeUV(current_coord.x, current_coord.y, configData.inf_cam[0], outputSize, h_out, v_out);
    if(inf_uv0.x >= 0.0 && inf_uv0.y >= 0.0 && inf_uv0.x < 640 && inf_uv0.y < 512)
    {
        int ix = int(inf_uv0.x);
        int iy = int(inf_uv0.y);
        inf_color0 = GetColor2(1, ix, iy);
        hasInfraredColor0 = true;
    }

    uint inf_color1 = uint(0);
    vec2 inf_uv1 = ComputeUV(current_coord.x, current_coord.y, configData.inf_cam[1], outputSize, h_out, v_out);
    if(inf_uv1.x >= 0.0 && inf_uv1.y >= 0.0 && inf_uv1.x < 640 && inf_uv1.y < 512)
    {
        int ix = int(inf_uv1.x);
        int iy = int(inf_uv1.y);
        inf_color1 = GetColor2(2, ix, iy);
        hasInfraredColor1 = true;
    }

    uint inf_color2 = uint(0);
    vec2 inf_uv2 = ComputeUV(current_coord.x, current_coord.y, configData.inf_cam[2], outputSize, h_out, v_out);
    if(inf_uv2.x >= 0.0 && inf_uv2.y >= 0.0 && inf_uv2.x < 640 && inf_uv2.y < 512)
    {
        int ix = int(inf_uv2.x);
        int iy = int(inf_uv2.y);
        inf_color2 = GetColor2(3, ix, iy);
        hasInfraredColor2 = true;
    }

    vec4 infraredRgba = vec4(0.0);
    if(hasInfraredColor0 && !hasInfraredColor1)
    {
        infraredRgba = unpackRGBA(inf_color0);
        infraredRate = pushConstants.infraredRate;
    }
    else if(hasInfraredColor0 && hasInfraredColor1)
    {
        vec4 inf_rgbaA = unpackRGBA(inf_color0);
        vec4 inf_rgbaB = unpackRGBA(inf_color1);
        float rate = InterpolateRate(float(current_coord.x), configData.inf_cam[0], configData.inf_cam[1], outputSize, h_out);
        infraredRgba = mix(inf_rgbaA, inf_rgbaB, rate);
        infraredRate = pushConstants.infraredRate;
    }
    else if(hasInfraredColor1 && !hasInfraredColor2)
    {
        infraredRgba = unpackRGBA(inf_color1);
        infraredRate = pushConstants.infraredRate;
    }
    else if(hasInfraredColor1 && hasInfraredColor2)
    {
        vec4 inf_rgbaA = unpackRGBA(inf_color1);
        vec4 inf_rgbaB = unpackRGBA(inf_color2);
        float rate = InterpolateRate(float(current_coord.x), configData.inf_cam[1], configData.inf_cam[2], outputSize, h_out);
        infraredRgba = mix(inf_rgbaA, inf_rgbaB, rate);
        infraredRate = pushConstants.infraredRate;
    }
    else if(!hasInfraredColor1 && hasInfraredColor2)
    {
        infraredRgba = unpackRGBA(inf_color2);
        infraredRate = pushConstants.infraredRate;
    }


    vec4 finalColor = mix(rgba, infraredRgba, infraredRate);
    imageStore(outputImage, current_coord, finalColor);
    
}