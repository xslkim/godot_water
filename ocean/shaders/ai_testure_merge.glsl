#[compute]
#version 450
#extension GL_EXT_samplerless_texture_functions : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform texture2D leftleft_tex;
layout(set = 0, binding = 1) uniform texture2D left_tex;
layout(set = 0, binding = 2) uniform texture2D front_tex;
layout(set = 0, binding = 3) uniform texture2D right_tex;
layout(set = 0, binding = 4) uniform texture2D rightright_tex;
layout(set = 0, binding = 5) uniform texture2D tir_left_tex;
layout(set = 0, binding = 6) uniform texture2D tir_front_tex;
layout(set = 0, binding = 7) uniform texture2D tir_right_tex;

layout(set = 0, binding = 8, rgba8) writeonly uniform image2D output_img;

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

layout(std140, set = 0, binding = 9) uniform ConfigUBO
{
    CameraParameter leftleft_camera;
    CameraParameter left_camera;
    CameraParameter front_camera;
    CameraParameter right_camera;
    CameraParameter rightright_camera;
    CameraParameter tir_left_camera;
    CameraParameter tir_front_camera;
    CameraParameter tir_right_camera;
    float tir_blend;
    float padding1;
    float padding2;
    float padding3;
} configData;

const float PI = 3.14159265359;
const float HORIZONTAL_FOV = 232.0; //142.0;
const float VERTICAL_FOV = 28.0;

float DegToRad(float deg) {
    return deg * PI / 180.0;
}

float RadToDeg(float rad) {
    return rad * 180.0 / PI;
}

// 3x3矩阵乘以向量
vec3 matMul(mat3 m, vec3 v) {
    return vec3(
        dot(m[0], v),
        dot(m[1], v),
        dot(m[2], v)
    );
}

// 将球面方向向量转换为相机像素坐标
bool SphereDirToCameraPixel(CameraParameter cam, vec3 sphere_dir, out vec2 pixel) {
    // 计算旋转矩阵的逆矩阵（旋转矩阵的逆等于其转置）
    float yaw = DegToRad(cam.rotation.y);
    float pitch = DegToRad(cam.rotation.x);
    float roll = DegToRad(cam.rotation.z);
    
    float cos_yaw = cos(yaw);
    float sin_yaw = sin(yaw);
    float cos_pitch = cos(pitch);
    float sin_pitch = sin(pitch);
    float cos_roll = cos(roll);
    float sin_roll = sin(roll);
    
    // Yaw逆旋转矩阵 (绕y轴)
    mat3 R_yaw_inv = mat3(
        cos_yaw, 0, sin_yaw,
        0, 1, 0,
        -sin_yaw, 0, cos_yaw
    );
    
    // Pitch逆旋转矩阵 (绕x轴)
    mat3 R_pitch_inv = mat3(
        1, 0, 0,
        0, cos_pitch, -sin_pitch,
        0, sin_pitch, cos_pitch
    );
    
    // Roll逆旋转矩阵 (绕z轴)
    mat3 R_roll_inv = mat3(
        cos_roll, -sin_roll, 0,
        sin_roll, cos_roll, 0,
        0, 0, 1
    );
    
    // 组合逆旋转矩阵: R_inv = R_roll_inv * R_pitch_inv * R_yaw_inv
    vec3 cam_dir = matMul(R_roll_inv, matMul(R_pitch_inv, matMul(R_yaw_inv, sphere_dir)));
    
    // 检查方向向量是否在相机前方
    if (cam_dir.z <= 0.0) {
        return false;
    }
    
    // 相机坐标系到像素坐标的转换
    float x = cam_dir.x / cam_dir.z;
    float y = cam_dir.y / cam_dir.z;
    
    pixel.x = x * cam.fx + cam.cx;
    pixel.y = y * cam.fy + cam.cy;
    
    // 检查像素坐标是否在相机视场内
    if (pixel.x < 0.0 || pixel.x >= cam.w || pixel.y < 0.0 || pixel.y >= cam.h) {
        return false;
    }
    
    return true;
}

// 从纹理获取颜色（带双线性插值）
vec4 GetColorBilinear(int pictureIndex, vec2 pixel) {
    ivec2 coord = ivec2(pixel);
    
    if (pictureIndex == 0) {
        return texelFetch(leftleft_tex, coord, 0);
    } else if (pictureIndex == 1) {
        return texelFetch(left_tex, coord, 0);
    } else if (pictureIndex == 2) {
        return texelFetch(front_tex, coord, 0);
    } else if (pictureIndex == 3) {
        return texelFetch(right_tex, coord, 0);
    } else if (pictureIndex == 4) {
        return texelFetch(rightright_tex, coord, 0);
    } else if (pictureIndex == 5) {
        return texelFetch(tir_left_tex, coord, 0);
    } else if (pictureIndex == 6) {
        return texelFetch(tir_front_tex, coord, 0);
    } else if (pictureIndex == 7) {
        return texelFetch(tir_right_tex, coord, 0);
    }
    
    return vec4(0.0);
}

// 将RGB颜色转换为亮度，然后映射为红色热成像效果
vec4 ConvertToThermalRed(vec4 color) {
    // 计算亮度 (使用标准的亮度公式)
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // 映射为红色渐变 (黑色->深红->亮红->黄色->白色)
    vec3 thermal_color;
    if (luminance < 0.25) {
        // 黑色到深红
        thermal_color = vec3(luminance * 4.0, 0.0, 0.0);
    } else if (luminance < 0.5) {
        // 深红到亮红
        float t = (luminance - 0.25) * 4.0;
        thermal_color = vec3(0.5 + t * 0.5, 0.0, 0.0);
    } else if (luminance < 0.75) {
        // 亮红到橙黄
        float t = (luminance - 0.5) * 4.0;
        thermal_color = vec3(1.0, t * 0.5, 0.0);
    } else {
        // 橙黄到白色
        float t = (luminance - 0.75) * 4.0;
        thermal_color = vec3(1.0, 0.5 + t * 0.5, t);
    }
    
    return vec4(thermal_color, color.a);
}

void main() 
{
    ivec2 outputSize = imageSize(output_img);
    ivec2 current_coord = ivec2(gl_GlobalInvocationID.xy);
    
    // 如果超出输出范围则返回
    if (current_coord.x >= outputSize.x || current_coord.y >= outputSize.y) {
        return;
    }
    
    // 计算当前像素对应的球面方向
    float u = float(current_coord.x) / float(outputSize.x);
    float v = float(current_coord.y) / float(outputSize.y);
    
    float horizontal_angle = (u - 0.5) * HORIZONTAL_FOV;
    float vertical_angle = (v - 0.5) * VERTICAL_FOV;
    
    // 将球面坐标转换为方向向量
    float hori_rad = DegToRad(horizontal_angle);
    float vert_rad = DegToRad(vertical_angle);
    
    float sin_vert = sin(vert_rad);
    float cos_vert = cos(vert_rad);
    
    vec3 sphere_dir = vec3(
        sin(hori_rad) * cos_vert,
        sin_vert,
        cos(hori_rad) * cos_vert
    );
    sphere_dir = normalize(sphere_dir);
    
    // 尝试从五个RGB相机中获取颜色
    vec4 leftleft_color = vec4(0.0);
    vec4 left_color = vec4(0.0);
    vec4 front_color = vec4(0.0);
    vec4 right_color = vec4(0.0);
    vec4 rightright_color = vec4(0.0);
    
    bool has_leftleft = false;
    bool has_left = false;
    bool has_front = false;
    bool has_right = false;
    bool has_rightright = false;
    
    // 左左相机
    vec2 leftleft_pixel;
    if (SphereDirToCameraPixel(configData.leftleft_camera, sphere_dir, leftleft_pixel)) {
        leftleft_color = GetColorBilinear(0, leftleft_pixel);
        has_leftleft = true;
    }
    
    // 左相机
    vec2 left_pixel;
    if (SphereDirToCameraPixel(configData.left_camera, sphere_dir, left_pixel)) {
        left_color = GetColorBilinear(1, left_pixel);
        has_left = true;
    }
    
    // 前相机
    vec2 front_pixel;
    if (SphereDirToCameraPixel(configData.front_camera, sphere_dir, front_pixel)) {
        front_color = GetColorBilinear(2, front_pixel);
        has_front = true;
    }
    
    // 右相机
    vec2 right_pixel;
    if (SphereDirToCameraPixel(configData.right_camera, sphere_dir, right_pixel)) {
        right_color = GetColorBilinear(3, right_pixel);
        has_right = true;
    }
    
    // 右右相机
    vec2 rightright_pixel;
    if (SphereDirToCameraPixel(configData.rightright_camera, sphere_dir, rightright_pixel)) {
        rightright_color = GetColorBilinear(4, rightright_pixel);
        has_rightright = true;
    }
    
    // 计算RGB相机的融合颜色
    int rgb_valid_count = 0;
    if (has_leftleft) rgb_valid_count++;
    if (has_left) rgb_valid_count++;
    if (has_front) rgb_valid_count++;
    if (has_right) rgb_valid_count++;
    if (has_rightright) rgb_valid_count++;
    
    vec4 rgb_color = vec4(0.0, 0.0, 0.0, 1.0);
    
    if (rgb_valid_count > 0) {
        float weight = 1.0 / float(rgb_valid_count);
        
        if (has_leftleft) {
            rgb_color.rgb += leftleft_color.rgb * weight;
        }
        if (has_left) {
            rgb_color.rgb += left_color.rgb * weight;
        }
        if (has_front) {
            rgb_color.rgb += front_color.rgb * weight;
        }
        if (has_right) {
            rgb_color.rgb += right_color.rgb * weight;
        }
        if (has_rightright) {
            rgb_color.rgb += rightright_color.rgb * weight;
        }
    }
    
    // 尝试从三个TIR相机中获取颜色
    vec4 tir_left_color = vec4(0.0);
    vec4 tir_front_color = vec4(0.0);
    vec4 tir_right_color = vec4(0.0);
    
    bool has_tir_left = false;
    bool has_tir_front = false;
    bool has_tir_right = false;
    
    // TIR左相机
    vec2 tir_left_pixel;
    if (SphereDirToCameraPixel(configData.tir_left_camera, sphere_dir, tir_left_pixel)) {
        vec4 raw_color = GetColorBilinear(5, tir_left_pixel);
        tir_left_color = ConvertToThermalRed(raw_color);
        has_tir_left = true;
    }
    
    // TIR前相机
    vec2 tir_front_pixel;
    if (SphereDirToCameraPixel(configData.tir_front_camera, sphere_dir, tir_front_pixel)) {
        vec4 raw_color = GetColorBilinear(6, tir_front_pixel);
        tir_front_color = ConvertToThermalRed(raw_color);
        has_tir_front = true;
    }
    
    // TIR右相机
    vec2 tir_right_pixel;
    if (SphereDirToCameraPixel(configData.tir_right_camera, sphere_dir, tir_right_pixel)) {
        vec4 raw_color = GetColorBilinear(7, tir_right_pixel);
        tir_right_color = ConvertToThermalRed(raw_color);
        has_tir_right = true;
    }
    
    // 计算TIR相机的融合颜色
    int tir_valid_count = 0;
    if (has_tir_left) tir_valid_count++;
    if (has_tir_front) tir_valid_count++;
    if (has_tir_right) tir_valid_count++;
    
    vec4 tir_color = vec4(0.0, 0.0, 0.0, 1.0);
    
    if (tir_valid_count > 0) {
        float weight = 1.0 / float(tir_valid_count);
        
        if (has_tir_left) {
            tir_color.rgb += tir_left_color.rgb * weight;
        }
        if (has_tir_front) {
            tir_color.rgb += tir_front_color.rgb * weight;
        }
        if (has_tir_right) {
            tir_color.rgb += tir_right_color.rgb * weight;
        }
    }
    
    // 根据tir_blend参数混合RGB和TIR颜色
    // tir_blend = 0: 只显示RGB
    // tir_blend = 1: 只显示TIR
    vec4 final_color = mix(rgb_color, tir_color, configData.tir_blend);
    
    imageStore(output_img, current_coord, final_color);
}