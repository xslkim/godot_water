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
    float left_gate_uni;   // 24
    float right_gate_uni;  // 28
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

struct CameraParameter {
    vec3 rotation; // 相机外参 旋转角度，单位：度
    float fx, fy;  // 相机内参 焦距
    float cx, cy;  // 相机内参 主点坐标
    float width, height; // 图像尺寸
};

// 将欧拉角转换为旋转矩阵
mat3 eulerToRotationMatrix(vec3 eulerDegrees) {
    vec3 radians = radians(eulerDegrees);
    float cosX = cos(radians.x);
    float sinX = sin(radians.x);
    float cosY = cos(radians.y);
    float sinY = sin(radians.y);
    float cosZ = cos(radians.z);
    float sinZ = sin(radians.z);
    
    mat3 Rx = mat3(
        1.0, 0.0, 0.0,
        0.0, cosX, -sinX,
        0.0, sinX, cosX
    );
    
    mat3 Ry = mat3(
        cosY, 0.0, sinY,
        0.0, 1.0, 0.0,
        -sinY, 0.0, cosY
    );
    
    mat3 Rz = mat3(
        cosZ, -sinZ, 0.0,
        sinZ, cosZ, 0.0,
        0.0, 0.0, 1.0
    );
    
    // 通常旋转顺序是 ZYX (yaw-pitch-roll)
    return Rz * Ry * Rx;
}

// 图像坐标到归一化相机坐标（无深度）
vec2 pixelToNormalized(CameraParameter cam, ivec2 pixelCoord) {
    return vec2(
        (float(pixelCoord.x) - cam.cx) / cam.fx,
        (float(pixelCoord.y) - cam.cy) / cam.fy
    );
}

// 归一化相机坐标到图像坐标
vec2 normalizedToPixel(CameraParameter cam, vec2 normalizedCoord) {
    return vec2(
        normalizedCoord.x * cam.fx + cam.cx,
        normalizedCoord.y * cam.fy + cam.cy
    );
}

/*
输入 
    1、原始相机参数 src_cam 
    2、目标相机参数 dst_cam
    3、目标相机投影面上的像素坐标 coord（二维）
输出
    在原始相机投影面的像素坐标
*/
vec2 single_camera(CameraParameter src_cam, CameraParameter dst_cam, ivec2 coord) {
    // 1. 将目标相机像素坐标转换为归一化相机坐标
    vec2 dst_normalized = pixelToNormalized(dst_cam, coord);
    
    // 2. 构建目标相机的方向向量（假设深度为1）
    vec3 dst_dir = normalize(vec3(dst_normalized, 1.0));
    
    // 3. 获取旋转矩阵
    mat3 R_dst = eulerToRotationMatrix(dst_cam.rotation);
    mat3 R_src = eulerToRotationMatrix(src_cam.rotation);
    
    // 4. 将方向向量从目标相机坐标系变换到世界坐标系，再变换到源相机坐标系
    // R_dst * dst_dir = 世界坐标系方向
    // R_src^T * (R_dst * dst_dir) = 源相机坐标系方向
    mat3 R_dst_inv = transpose(R_dst); // 旋转矩阵的逆等于转置
    vec3 src_dir = R_src * (R_dst_inv * dst_dir);
    
    // 5. 将源相机坐标系的方向向量投影到归一化图像平面
    if (abs(src_dir.z) < 1e-6) {
        // 方向与图像平面平行，无法投影
        return vec2(-1.0, -1.0);
    }
    
    vec2 src_normalized = vec2(src_dir.x / src_dir.z, src_dir.y / src_dir.z);
    
    // 6. 将归一化坐标转换回像素坐标
    return normalizedToPixel(src_cam, src_normalized);
}


void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_img);
    if (coord.x >= size.x || coord.y >= size.y) 
    {
        return;
    }

    // float h_output_fov = fov_x_uni;
    // float h_AngleRate = float(coord.x) / float(size.x) - 0.5f;
    // float h_Angle = h_AngleRate * h_output_fov;

    // float v_output_fov = float(coord.y) / size.y - 0.5f;
    // float v_Angle = v_output_fov * 28;

    float h_dir_angle = float(coord.x) / float(size.x) * fov_x_uni;
    float gate_x = (45.0f/97.0f) * float(size.x);

    if( h_dir_angle < 45 ) {
        vec4 left = texelFetch(left_tex, coord, 0); 
        imageStore(output_img, coord, left);
    }
    else if(h_dir_angle < 52)
    {
        // 中间区域，进行投影变换
        CameraParameter center_cam;
        center_cam.rotation = vec3(0.0, 0.0, 0.0);
        center_cam.fx = fx_uni;
        center_cam.fy = fy_uni;
        center_cam.cx = cx_uni;
        center_cam.cy = cy_uni;
        center_cam.width = width_uni;
        center_cam.height = height_uni;

        float right_rotate_angle = 10;
        CameraParameter right_cam;
        right_cam.rotation = vec3(0, right_rotate_angle, 0);
        right_cam.fx = fx_uni;
        right_cam.fy = fy_uni;
        right_cam.cx = width_uni/2;
        right_cam.cy = height_uni/2;
        right_cam.width = width_uni;
        right_cam.height = height_uni;

        //ivec2 coord_1_2 = ivec2(coord.x - gate_x, coord.y);

        float cur_angle = h_dir_angle - right_rotate_angle;
        float right_angle = cur_angle - (52 / 2);
        float tan_right = tan(radians(right_angle));
        float right_pielx = fx_uni * tan_right;
        float right_cam_pielx = right_pielx + cx_uni;

        ivec2 coord_1_2 = ivec2(right_cam_pielx, coord.y);
        vec2 p_original = single_camera(center_cam, right_cam, coord_1_2);
        ivec2 p_original_ivec = ivec2(int(round(p_original.x)), int(round(p_original.y)));

        vec4 left = texelFetch(left_tex, p_original_ivec, 0);  
        imageStore(output_img, coord, left);
    }
    // else
    // {
    //     imageStore(output_img, coord, vec4(0, 0, 1, 1));
    // }


   
    // vec4 left = texelFetch(left_tex, p_original_ivec, 0);  
    // //vec4 right = texelFetch(right_tex, coord, 0);

    // vec4 result = left; //(left + right) * 0.5;
    // imageStore(output_img, coord, result);
}