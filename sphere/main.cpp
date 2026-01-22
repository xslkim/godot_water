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
std::vector<std::vector<vec4>> sphereData(142*10, std::vector<vec4>(32*10));

// 从相机像素坐标到球面坐标的转换
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
    // 水平方向：142度，每度10个像素
    // 垂直方向：32度，每度10个像素
    // 水平角范围：-71到71度
    // 垂直角范围：-16到16度
    
    int h_index = static_cast<int>((horizontal_angle - (-71)) * 10);
    int v_index = static_cast<int>((vertical_angle - (-16)) * 10);
    
    // 确保索引在有效范围内
    h_index = std::max(0, std::min(h_index, 142*10 - 1));
    v_index = std::max(0, std::min(v_index, 32*10 - 1));
    
    return ivec2(h_index, v_index);
}

// 将球面数据投影到输出图片
void ProjectSphereToOutput(const std::vector<std::vector<vec4>>& sphere_data, std::vector<unsigned char>& output_data, int output_width, int output_height) {
    for (int y = 0; y < output_height; y++) {
        for (int x = 0; x < output_width; x++) {
            // 计算当前像素对应的球面方向
            float u = static_cast<float>(x) / output_width;
            float v = static_cast<float>(y) / output_height;
            
            float horizontal_angle = (u - 0.5f) * 142;
            float vertical_angle = (v - 0.5f) * 32;
            
            // 转换为球面数据索引
            ivec2 index = SphereAngleToIndex(horizontal_angle, vertical_angle);
            
            // 获取球面数据
            vec4 color = sphere_data[index.x][index.y];
            
            // 写入输出图片
            int idx = (y * output_width + x) * 4;
            output_data[idx] = static_cast<unsigned char>(color.x * 255);
            output_data[idx + 1] = static_cast<unsigned char>(color.y * 255);
            output_data[idx + 2] = static_cast<unsigned char>(color.z * 255);
            output_data[idx + 3] = static_cast<unsigned char>(color.w * 255);
        }
    }
}

int main()
{
    // 读取三个相机的图片
    int left_width, left_height, left_channels;
    unsigned char* left_data = stbi_load("img/left_cam.png", &left_width, &left_height, &left_channels, 4);
    if (!left_data) {
        std::cerr << "Failed to load left_cam.png" << std::endl;
        return 1;
    }
    
    int front_width, front_height, front_channels;
    unsigned char* front_data = stbi_load("img/front_cam.png", &front_width, &front_height, &front_channels, 4);
    if (!front_data) {
        std::cerr << "Failed to load front_cam.png" << std::endl;
        stbi_image_free(left_data);
        return 1;
    }
    
    int right_width, right_height, right_channels;
    unsigned char* right_data = stbi_load("img/right_cam.png", &right_width, &right_height, &right_channels, 4);
    if (!right_data) {
        std::cerr << "Failed to load right_cam.png" << std::endl;
        stbi_image_free(left_data);
        stbi_image_free(front_data);
        return 1;
    }
    
    // 初始化球面数据为黑色
    for (int i = 0; i < sphereData.size(); i++) {
        for (int j = 0; j < sphereData[i].size(); j++) {
            sphereData[i][j] = vec4(0, 0, 0, 1);
        }
    }
    
    // 处理左相机
    std::cout << "Processing left camera..." << std::endl;
    for (int y = 0; y < left_height; y++) {
        for (int x = 0; x < left_width; x++) {
            int idx = (y * left_width + x) * 4;
            vec4 color(
                left_data[idx] / 255.0f,
                left_data[idx + 1] / 255.0f,
                left_data[idx + 2] / 255.0f,
                left_data[idx + 3] / 255.0f
            );
            
            vec2 pixel(x, y);
            vec3 sphere_dir;
            ProjectPixelToSphere(configData.left_camera, pixel, sphere_dir);
            
            float horizontal_angle, vertical_angle;
            SphereDirToAngle(sphere_dir, horizontal_angle, vertical_angle);
            
            ivec2 sphere_index = SphereAngleToIndex(horizontal_angle, vertical_angle);
            sphereData[sphere_index.x][sphere_index.y] = color;
        }
    }
    
    // 处理前相机
    std::cout << "Processing front camera..." << std::endl;
    for (int y = 0; y < front_height; y++) {
        for (int x = 0; x < front_width; x++) {
            int idx = (y * front_width + x) * 4;
            vec4 color(
                front_data[idx] / 255.0f,
                front_data[idx + 1] / 255.0f,
                front_data[idx + 2] / 255.0f,
                front_data[idx + 3] / 255.0f
            );
            
            vec2 pixel(x, y);
            vec3 sphere_dir;
            ProjectPixelToSphere(configData.front_camera, pixel, sphere_dir);
            
            float horizontal_angle, vertical_angle;
            SphereDirToAngle(sphere_dir, horizontal_angle, vertical_angle);
            
            ivec2 sphere_index = SphereAngleToIndex(horizontal_angle, vertical_angle);
            sphereData[sphere_index.x][sphere_index.y] = color;
        }
    }
    
    // 处理右相机
    std::cout << "Processing right camera..." << std::endl;
    for (int y = 0; y < right_height; y++) {
        for (int x = 0; x < right_width; x++) {
            int idx = (y * right_width + x) * 4;
            vec4 color(
                right_data[idx] / 255.0f,
                right_data[idx + 1] / 255.0f,
                right_data[idx + 2] / 255.0f,
                right_data[idx + 3] / 255.0f
            );
            
            vec2 pixel(x, y);
            vec3 sphere_dir;
            ProjectPixelToSphere(configData.right_camera, pixel, sphere_dir);
            
            float horizontal_angle, vertical_angle;
            SphereDirToAngle(sphere_dir, horizontal_angle, vertical_angle);
            
            ivec2 sphere_index = SphereAngleToIndex(horizontal_angle, vertical_angle);
            sphereData[sphere_index.x][sphere_index.y] = color;
        }
    }
    
    // 释放图片数据
    stbi_image_free(left_data);
    stbi_image_free(front_data);
    stbi_image_free(right_data);
    
    // 创建输出图片
    int output_width = 1420;
    int output_height = 320;
    std::vector<unsigned char> output_data(output_width * output_height * 4);
    
    // 将球面数据投影到输出图片
    std::cout << "Projecting sphere to output image..." << std::endl;
    ProjectSphereToOutput(sphereData, output_data, output_width, output_height);
    
    // 保存输出图片
    std::cout << "Saving output image..." << std::endl;
    stbi_write_png("output.png", output_width, output_height, 4, output_data.data(), output_width * 4);
    
    std::cout << "Done! Output saved to output.png" << std::endl;
    
    return 0;
}