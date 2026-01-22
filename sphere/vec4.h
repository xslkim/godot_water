#pragma once

#include <iostream>
#include <cmath>
#include "ivec2.h" // 假设 vec2 在这里定义
#include "vec3.h"  // 引入 vec3，以便在 vec4 中使用



// vec4 类
class vec4 {
public:
    float x, y, z, w;

    // 构造函数
    vec4(float x = 0, float y = 0, float z = 0, float w = 0) : x(x), y(y), z(z), w(w) {}
    vec4(vec2 xy, float z = 0, float w = 0) : x(xy.x), y(xy.y), z(z), w(w) {} // 使用 vec2 初始化 xy
    vec4(vec3 xyz, float w = 0) : x(xyz.x), y(xyz.y), z(xyz.z), w(w) {}       // 使用 vec3 初始化 xyz

    // 获取分量
    float getX() const { return x; }
    float getY() const { return y; }
    float getZ() const { return z; }
    float getW() const { return w; }

    // 设置分量
    void setX(float val) { x = val; }
    void setY(float val) { y = val; }
    void setZ(float val) { z = val; }
    void setW(float val) { w = val; }

    // 向量运算
    vec4 operator+(const vec4& other) const {
        return vec4(x + other.x, y + other.y, z + other.z, w + other.w);
    }

    vec4 operator-(const vec4& other) const {
        return vec4(x - other.x, y - other.y, z - other.z, w - other.w);
    }

    vec4 operator*(float scalar) const {
        return vec4(x * scalar, y * scalar, z * scalar, w * scalar);
    }

    vec4 operator/(float scalar) const {
        return vec4(x / scalar, y / scalar, z / scalar, w / scalar);
    }

    friend vec4 operator*(float scalar, const vec4& vec) {
        return vec * scalar;
    }

    // 点积 (4D 空间中的点积)
    float dot(const vec4& other) const {
        return x * other.x + y * other.y + z * other.z + w * other.w;
    }

    // 长度 (4D 空间中的长度)
    float length() const {
        return std::sqrt(x * x + y * y + z * z + w * w);
    }

    // 归一化 (4D 空间中的归一化)
    vec4 normalize() const {
        float len = length();
        if (len > 0.0f) {
            return *this / len;
        }
        // 如果长度为零，返回原向量或零向量，这里选择返回原向量
        return *this;
    }

    // 调试输出
    void print(const std::string& name = "") const {
        if (!name.empty()) {
            std::cout << name << " = ";
        }
        std::cout << "(" << x << ", " << y << ", " << z << ", " << w << ")" << std::endl;
    }

    // 转换为字符串
    std::string to_string() const {
        char buffer[128]; // 缓冲区需要更大一些
        snprintf(buffer, sizeof(buffer), "(%.4f, %.4f, %.4f, %.4f)", x, y, z, w);
        return std::string(buffer);
    }
};

// 全局归一化函数 (GLSL 风格)
inline vec4 normalize(vec4 in) {
    return in.normalize();
}

// GLSL 风格的 radians 函数 (4D 版本)
// 将角度转换为弧度
inline vec4 radians(const vec4& degrees) {
    return vec4(
        degrees.getX() * DEG_TO_RAD,
        degrees.getY() * DEG_TO_RAD,
        degrees.getZ() * DEG_TO_RAD,
        degrees.getW() * DEG_TO_RAD
    );
}

// GLSL 风格的 degrees 函数 (4D 版本)
// 将弧度转换为角度
inline vec4 degrees(const vec4& radians) {
    return vec4(
        radians.getX() * 180.0f / PI,
        radians.getY() * 180.0f / PI,
        radians.getZ() * 180.0f / PI,
        radians.getW() * 180.0f / PI
    );
}