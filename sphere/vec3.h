#pragma once

#include <iostream>
#include <cmath>
#include "ivec2.h"

// 角度转弧度常量
const float PI = 3.14159265358979323846f;
const float DEG_TO_RAD = PI / 180.0f;

// vec3 类
class vec3 {
public:
    float x, y, z;
    
    // 构造函数
    vec3(float x = 0, float y = 0, float z = 0) : x(x), y(y), z(z) {}
    vec3(vec2 xy, float z = 0) : x(xy.x), y(xy.y), z(z) {}
    
    // 获取分量
    float getX() const { return x; }
    float getY() const { return y; }
    float getZ() const { return z; }
    
    // 设置分量
    void setX(float val) { x = val; }
    void setY(float val) { y = val; }
    void setZ(float val) { z = val; }
    
    // 向量运算
    vec3 operator+(const vec3& other) const {
        return vec3(x + other.x, y + other.y, z + other.z);
    }
    
    vec3 operator-(const vec3& other) const {
        return vec3(x - other.x, y - other.y, z - other.z);
    }
    
    vec3 operator*(float scalar) const {
        return vec3(x * scalar, y * scalar, z * scalar);
    }
    
    vec3 operator/(float scalar) const {
        return vec3(x / scalar, y / scalar, z / scalar);
    }
    
    friend vec3 operator*(float scalar, const vec3& vec) {
        return vec * scalar;
    }
    
    // 点积
    float dot(const vec3& other) const {
        return x * other.x + y * other.y + z * other.z;
    }
    
    // 叉积
    vec3 cross(const vec3& other) const {
        return vec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        );
    }
    
    // 长度
    float length() const {
        return std::sqrt(x * x + y * y + z * z);
    }
    
    // 归一化
    vec3 normalize() const {
        float len = length();
        if (len > 0.0f) {
            return *this / len;
        }
        return *this;
    }
    
    // 调试输出
    void print(const std::string& name = "") const {
        if (!name.empty()) {
            std::cout << name << " = ";
        }
        std::cout << "(" << x << ", " << y << ", " << z << ")" << std::endl;
    }
    
    // 转换为字符串
    std::string to_string() const {
        char buffer[64];
        snprintf(buffer, sizeof(buffer), "(%.4f, %.4f, %.4f)", x, y, z);
        return std::string(buffer);
    }
};

inline vec3 normalize(vec3 in){
    return in.normalize();
}

// GLSL 风格的 radians 函数
// 将角度转换为弧度

// 1. float 版本
inline float radians(float degrees) {
    return degrees * DEG_TO_RAD;
}

// 2. vec3 版本
inline vec3 radians(const vec3& degrees) {
    return vec3(
        degrees.getX() * DEG_TO_RAD,
        degrees.getY() * DEG_TO_RAD,
        degrees.getZ() * DEG_TO_RAD
    );
}

// 为了方便，也提供 degrees 函数（弧度转角度）
// 3. float 版本
inline float degrees(float radians) {
    return radians * 180.0f / PI;
}

// 4. vec3 版本
inline vec3 degrees(const vec3& radians) {
    return vec3(
        degrees(radians.getX()),
        degrees(radians.getY()),
        degrees(radians.getZ())
    );
}