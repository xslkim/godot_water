#include <cmath>
#include <vector>
#include <algorithm>
#include <iostream>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include "ivec2.h"
#include "mat3.h"
#include "vec3.h"
#include "vec4.h"

// 球面投影相关常量
const float HORIZONTAL_FOV = 142.0f;    // 水平视场角
const float HORIZONTAL_FOV_HALF = 71.0f; // 水平视场角的一半
const float VERTICAL_FOV = 28.0f;        // 垂直视场角
const float VERTICAL_FOV_HALF = 14.0f;   // 垂直视场角的一半
const int PIXELS_PER_DEGREE = 40;        // 每度的像素数（扩大4倍）
const int SPHERE_WIDTH = static_cast<int>(HORIZONTAL_FOV * PIXELS_PER_DEGREE);  // 球面数据宽度
const int SPHERE_HEIGHT = static_cast<int>(VERTICAL_FOV * PIXELS_PER_DEGREE);    // 球面数据高度

inline float DegToRad(float deg) {
    return deg * PI / 180.0f;
}

inline float RadToDeg(float rad) {
    return rad * 180.0f / PI;
}

//每个相机的外参和内参，所有相机都位于一个光心，所以没有位置参数
struct CameraParameter {
    vec4 rotation;
    float fx = 1968;
    float fy = 1968;
    float cx = 1920/2;
    float cy = 1080/2;
    float w = 1920;
    float h = 1080;
    float padding1;
    float padding2;
};

// 配置UBO，包含三个相机的参数, 除了航向角，其他参数都采用默认值
struct ConfigUBO
{
    CameraParameter left_camera;
    CameraParameter front_camera;
    CameraParameter right_camera;
    ConfigUBO() {
        // left_camera.rotation.y = -45;

        // front_camera.rotation.x = 5;
        // front_camera.rotation.y = -5;
        // front_camera.rotation.z = -3;

        // right_camera.rotation.x = -2;
        // right_camera.rotation.y = 45;
        // right_camera.rotation.z = -5;

        left_camera.rotation.y = -45;
        right_camera.rotation.y = 45;
    }
}configData;

//左边相机拍摄到的图像，保存在leftImage中
std::vector<std::vector<vec4>> leftImage(configData.left_camera.h, std::vector<vec4>(configData.left_camera.w));

// 前相机拍摄到的图像，保存在frontImage中
std::vector<std::vector<vec4>> frontImage(configData.front_camera.h, std::vector<vec4>(configData.front_camera.w));

// 右相机拍摄到的图像，保存在rightImage中
std::vector<std::vector<vec4>> rightImage(configData.right_camera.h, std::vector<vec4>(configData.right_camera.w));

//水平方向为142度，垂直方向为32度，每一度可以分割为水平垂直10*10个像素点，每个像素点保存一个vec4，分别为RGB和透明度
std::vector<std::vector<vec4>> sphereData(SPHERE_WIDTH, std::vector<vec4>(SPHERE_HEIGHT));

// 将相机像素坐标转换为球面方向向量，考虑相机的内参和外参
void ProjectPixelToSphere(const CameraParameter& cam, const vec2& pixel, vec3& sphere_dir) {
    // 像素坐标到相机坐标系
    float x = (pixel.x - cam.cx) / cam.fx;
    float y = (pixel.y - cam.cy) / cam.fy;
    vec3 ray_dir(x, y, 1.0f);
    ray_dir = normalize(ray_dir);
    
    // 应用相机旋转
    float yaw = DegToRad(cam.rotation.y);
    float pitch = DegToRad(cam.rotation.x);
    float roll = DegToRad(cam.rotation.z);
    
    // 计算旋转矩阵
    float cos_yaw = cos(yaw);
    float sin_yaw = sin(yaw);
    float cos_pitch = cos(pitch);
    float sin_pitch = sin(pitch);
    float cos_roll = cos(roll);
    float sin_roll = sin(roll);
    
    // Yaw rotation (around y-axis) - column major order
    mat3 R_yaw(cos_yaw, 0, -sin_yaw,
               0, 1, 0,
               sin_yaw, 0, cos_yaw);
    
    // Pitch rotation (around x-axis) - column major order
    mat3 R_pitch(1, 0, 0,
                 0, cos_pitch, sin_pitch,
                 0, -sin_pitch, cos_pitch);
    
    // Roll rotation (around z-axis) - column major order
    mat3 R_roll(cos_roll, sin_roll, 0,
                -sin_roll, cos_roll, 0,
                0, 0, 1);
    
    // 组合旋转
    mat3 R = R_yaw * R_pitch * R_roll;
    sphere_dir = R * ray_dir;
    sphere_dir = normalize(sphere_dir);
}

// 将球面方向向量转换为球面坐标（水平角和垂直角）
void SphereDirToAngle(const vec3& dir, float& horizontal_angle, float& vertical_angle) {
    horizontal_angle = atan2(dir.x, dir.z);
    horizontal_angle = RadToDeg(horizontal_angle);
    // 保持水平角范围在-180到180度
    
    vertical_angle = asin(dir.y);
    vertical_angle = RadToDeg(vertical_angle);
}

// 从球面坐标计算球面数据的索引
ivec2 SphereAngleToIndex(float horizontal_angle, float vertical_angle) {
    // 水平方向：HORIZONTAL_FOV度，每度PIXELS_PER_DEGREE个像素
    // 垂直方向：VERTICAL_FOV度，每度PIXELS_PER_DEGREE个像素
    // 水平角范围：-HORIZONTAL_FOV_HALF到HORIZONTAL_FOV_HALF度
    // 垂直角范围：-VERTICAL_FOV_HALF到VERTICAL_FOV_HALF度
    
    int h_index = static_cast<int>((horizontal_angle - (-HORIZONTAL_FOV_HALF)) * PIXELS_PER_DEGREE);
    int v_index = static_cast<int>((vertical_angle - (-VERTICAL_FOV_HALF)) * PIXELS_PER_DEGREE);
    
    // 确保索引在有效范围内
    h_index = std::max(0, std::min(h_index, SPHERE_WIDTH - 1));
    v_index = std::max(0, std::min(v_index, SPHERE_HEIGHT - 1));
    
    return ivec2(h_index, v_index);
}

// 将球面方向向量转换为相机像素坐标
bool SphereDirToCameraPixel(const CameraParameter& cam, const vec3& sphere_dir, vec2& pixel) {
    // 应用相机旋转的逆变换，将球面方向向量转换到相机坐标系
    float yaw = DegToRad(cam.rotation.y);
    float pitch = DegToRad(cam.rotation.x);
    float roll = DegToRad(cam.rotation.z);
    
    // 计算旋转矩阵的逆矩阵（旋转矩阵的逆等于其转置）
    float cos_yaw = cos(yaw);
    float sin_yaw = sin(yaw);
    float cos_pitch = cos(pitch);
    float sin_pitch = sin(pitch);
    float cos_roll = cos(roll);
    float sin_roll = sin(roll);
    
    // 计算逆旋转矩阵
    mat3 R_yaw_inv(cos_yaw, 0, sin_yaw,
                   0, 1, 0,
                   -sin_yaw, 0, cos_yaw);
    
    mat3 R_pitch_inv(1, 0, 0,
                     0, cos_pitch, -sin_pitch,
                     0, sin_pitch, cos_pitch);
    
    mat3 R_roll_inv(cos_roll, -sin_roll, 0,
                    sin_roll, cos_roll, 0,
                    0, 0, 1);
    
    // 组合逆旋转矩阵
    mat3 R_inv = R_roll_inv * R_pitch_inv * R_yaw_inv;
    vec3 cam_dir = R_inv * sphere_dir;
    
    // 检查方向向量是否在相机前方
    if (cam_dir.z <= 0) {
        return false;
    }
    
    // 相机坐标系到像素坐标的转换
    float x = cam_dir.x / cam_dir.z;
    float y = cam_dir.y / cam_dir.z;
    
    pixel.x = x * cam.fx + cam.cx;
    pixel.y = y * cam.fy + cam.cy;
    
    // 检查像素坐标是否在相机视场内
    if (pixel.x < 0 || pixel.x >= cam.w || pixel.y < 0 || pixel.y >= cam.h) {
        return false;
    }
    
    return true;
}

// 直接计算输出图片的像素值
void ComputeOutputImage(const unsigned char* left_data, int left_width, int left_height,
                       const unsigned char* front_data, int front_width, int front_height,
                       const unsigned char* right_data, int right_width, int right_height,
                       std::vector<unsigned char>& output_data, int output_width, int output_height) {
    for (int y = 0; y < output_height; y++) {
        for (int x = 0; x < output_width; x++) {
            // 计算当前像素对应的球面方向
            float u = static_cast<float>(x) / output_width;
            float v = static_cast<float>(y) / output_height;
            
            float horizontal_angle = (u - 0.5f) * HORIZONTAL_FOV;
            float vertical_angle = (v - 0.5f) * VERTICAL_FOV;
            
            // 将球面坐标转换为方向向量
            float hori_rad = DegToRad(horizontal_angle);
            float vert_rad = DegToRad(vertical_angle);
            
            float sin_vert = sin(vert_rad);
            float cos_vert = cos(vert_rad);
            vec3 sphere_dir(
                sin(hori_rad) * cos_vert,
                sin_vert,
                cos(hori_rad) * cos_vert
            );
            sphere_dir = normalize(sphere_dir);
            
            // 尝试从三个相机中获取颜色
            vec4 left_color(0, 0, 0, 0);
            vec4 front_color(0, 0, 0, 0);
            vec4 right_color(0, 0, 0, 0);
            
            // 左相机
            vec2 left_pixel;
            if (SphereDirToCameraPixel(configData.left_camera, sphere_dir, left_pixel)) {
                int left_x = static_cast<int>(left_pixel.x);
                int left_y = static_cast<int>(left_pixel.y);
                int left_idx = (left_y * left_width + left_x) * 4;
                left_color = vec4(
                    left_data[left_idx] / 255.0f,
                    left_data[left_idx + 1] / 255.0f,
                    left_data[left_idx + 2] / 255.0f,
                    left_data[left_idx + 3] / 255.0f
                );
            }
            
            // 前相机
            vec2 front_pixel;
            if (SphereDirToCameraPixel(configData.front_camera, sphere_dir, front_pixel)) {
                int front_x = static_cast<int>(front_pixel.x);
                int front_y = static_cast<int>(front_pixel.y);
                int front_idx = (front_y * front_width + front_x) * 4;
                front_color = vec4(
                    front_data[front_idx] / 255.0f,
                    front_data[front_idx + 1] / 255.0f,
                    front_data[front_idx + 2] / 255.0f,
                    front_data[front_idx + 3] / 255.0f
                );
            }
            
            // 右相机
            vec2 right_pixel;
            if (SphereDirToCameraPixel(configData.right_camera, sphere_dir, right_pixel)) {
                int right_x = static_cast<int>(right_pixel.x);
                int right_y = static_cast<int>(right_pixel.y);
                int right_idx = (right_y * right_width + right_x) * 4;
                right_color = vec4(
                    right_data[right_idx] / 255.0f,
                    right_data[right_idx + 1] / 255.0f,
                    right_data[right_idx + 2] / 255.0f,
                    right_data[right_idx + 3] / 255.0f
                );
            }
            
            // 计算有效颜色的数量
            int valid_count = 0;
            if (left_color.w > 0) valid_count++;
            if (front_color.w > 0) valid_count++;
            if (right_color.w > 0) valid_count++;
            
            // 融合颜色
            vec4 final_color(0, 0, 0, 1);
            if (valid_count > 0) {
                // 计算权重
                float weight = 1.0f / valid_count;
                
                if (left_color.w > 0) {
                    final_color.x += left_color.x * weight;
                    final_color.y += left_color.y * weight;
                    final_color.z += left_color.z * weight;
                }
                if (front_color.w > 0) {
                    final_color.x += front_color.x * weight;
                    final_color.y += front_color.y * weight;
                    final_color.z += front_color.z * weight;
                }
                if (right_color.w > 0) {
                    final_color.x += right_color.x * weight;
                    final_color.y += right_color.y * weight;
                    final_color.z += right_color.z * weight;
                }
            }
            
            // 写入输出图片
            int idx = (y * output_width + x) * 4;
            output_data[idx] = static_cast<unsigned char>(final_color.x * 255);
            output_data[idx + 1] = static_cast<unsigned char>(final_color.y * 255);
            output_data[idx + 2] = static_cast<unsigned char>(final_color.z * 255);
            output_data[idx + 3] = static_cast<unsigned char>(final_color.w * 255);
        }
    }
}

int main()
{
    // 读取三个相机的图片
    int left_width, left_height, left_channels;
    unsigned char* left_data = stbi_load("img/left.png", &left_width, &left_height, &left_channels, 4);
    if (!left_data) {
        std::cerr << "Failed to load left.png" << std::endl;
        return 1;
    }
    
    int front_width, front_height, front_channels;
    unsigned char* front_data = stbi_load("img/front.png", &front_width, &front_height, &front_channels, 4);
    if (!front_data) {
        std::cerr << "Failed to load front.png" << std::endl;
        stbi_image_free(left_data);
        return 1;
    }
    
    int right_width, right_height, right_channels;
    unsigned char* right_data = stbi_load("img/right.png", &right_width, &right_height, &right_channels, 4);
    if (!right_data) {
        std::cerr << "Failed to load right_cam.png" << std::endl;
        stbi_image_free(left_data);
        stbi_image_free(front_data);
        return 1;
    }
    
    // 创建输出图片
    int output_width = SPHERE_WIDTH;
    int output_height = SPHERE_HEIGHT;
    std::vector<unsigned char> output_data(output_width * output_height * 4);
    
    // 直接计算输出图片的像素值
    std::cout << "Computing output image..." << std::endl;
    ComputeOutputImage(left_data, left_width, left_height,
                      front_data, front_width, front_height,
                      right_data, right_width, right_height,
                      output_data, output_width, output_height);
    
    // 释放图片数据
    stbi_image_free(left_data);
    stbi_image_free(front_data);
    stbi_image_free(right_data);
    
    // 保存输出图片
    std::cout << "Saving output image..." << std::endl;
    stbi_write_png("output.png", output_width, output_height, 4, output_data.data(), output_width * 4);
    
    std::cout << "Done! Output saved to output.png" << std::endl;
    
    return 0;
}