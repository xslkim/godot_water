#ifndef __MAT3_H__
#define __MAT3_H__

#include <iostream>
#include <iomanip>
#include <cmath>
#include <array>
#include <cassert>
#include "vec3.h"

class mat3 {
private:
    // 使用列优先存储，与GLSL一致
    // [0] [3] [6]
    // [1] [4] [7]
    // [2] [5] [8]
    std::array<float, 9> data;

public:
    // 构造函数
    mat3() : data{1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f} {}  // 单位矩阵
    
    explicit mat3(float diagonal) 
        : data{diagonal, 0.0f, 0.0f, 0.0f, diagonal, 0.0f, 0.0f, 0.0f, diagonal} {}
    
    mat3(float m00, float m10, float m20,
         float m01, float m11, float m21,
         float m02, float m12, float m22)
        : data{m00, m10, m20, m01, m11, m21, m02, m12, m22} {}
    
    // 从数组构造
    explicit mat3(const float arr[9]) {
        for (int i = 0; i < 9; ++i) data[i] = arr[i];
    }
    
    // 访问元素（行优先访问，但内部是列优先存储）
    float& operator()(int row, int col) {
        // col * 3 + row 转换为列优先索引
        return data[col * 3 + row];
    }
    
    const float& operator()(int row, int col) const {
        return data[col * 3 + row];
    }
    
    // 获取原始数据（列优先）
    const float* value_ptr() const { return data.data(); }
    
    // 矩阵运算
    mat3 operator+(const mat3& other) const {
        mat3 result;
        for (int i = 0; i < 9; ++i) {
            result.data[i] = data[i] + other.data[i];
        }
        return result;
    }
    
    mat3 operator-(const mat3& other) const {
        mat3 result;
        for (int i = 0; i < 9; ++i) {
            result.data[i] = data[i] - other.data[i];
        }
        return result;
    }
    
    mat3 operator*(const mat3& other) const {
        mat3 result(0.0f);
        for (int i = 0; i < 3; ++i) {        // 行
            for (int j = 0; j < 3; ++j) {    // 列
                float sum = 0.0f;
                for (int k = 0; k < 3; ++k) {
                    sum += (*this)(i, k) * other(k, j);
                }
                result(i, j) = sum;
            }
        }
        return result;
    }

    // ========== 关键实现：矩阵乘以向量 ==========
    // 矩阵在左，向量在右：mat3 * vec3
    vec3 operator*(const vec3& v) const {
        // 矩阵乘法：M * v
        // 对于列向量 v，结果是 M * v
        // 对于行向量 v，结果是 v * M^T
        // 这里实现 GLSL 风格的 M * v
        return vec3(
            (*this)(0,0) * v.getX() + (*this)(0,1) * v.getY() + (*this)(0,2) * v.getZ(),
            (*this)(1,0) * v.getX() + (*this)(1,1) * v.getY() + (*this)(1,2) * v.getZ(),
            (*this)(2,0) * v.getX() + (*this)(2,1) * v.getY() + (*this)(2,2) * v.getZ()
        );
    }
    
    mat3 operator*(float scalar) const {
        mat3 result;
        for (int i = 0; i < 9; ++i) {
            result.data[i] = data[i] * scalar;
        }
        return result;
    }
    
    friend mat3 operator*(float scalar, const mat3& mat) {
        return mat * scalar;
    }
    
    mat3& operator+=(const mat3& other) {
        for (int i = 0; i < 9; ++i) {
            data[i] += other.data[i];
        }
        return *this;
    }
    
    mat3& operator-=(const mat3& other) {
        for (int i = 0; i < 9; ++i) {
            data[i] -= other.data[i];
        }
        return *this;
    }
    
    mat3& operator*=(const mat3& other) {
        *this = *this * other;
        return *this;
    }
    
    mat3& operator*=(float scalar) {
        for (int i = 0; i < 9; ++i) {
            data[i] *= scalar;
        }
        return *this;
    }
    
    // 转置
    mat3 transpose() const {
        mat3 result;
        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 3; ++j) {
                result(i, j) = (*this)(j, i);
            }
        }
        return result;
    }
    
    // 行列式
    float determinant() const {
        return (*this)(0,0)*(*this)(1,1)*(*this)(2,2) +
               (*this)(0,1)*(*this)(1,2)*(*this)(2,0) +
               (*this)(0,2)*(*this)(1,0)*(*this)(2,1) -
               (*this)(0,2)*(*this)(1,1)*(*this)(2,0) -
               (*this)(0,1)*(*this)(1,0)*(*this)(2,2) -
               (*this)(0,0)*(*this)(1,2)*(*this)(2,1);
    }
    
    // 逆矩阵
    mat3 inverse() const {
        float det = determinant();
        if (std::fabs(det) < 1e-8f) {
            std::cerr << "Warning: matrix is singular, cannot compute inverse" << std::endl;
            return mat3();
        }
        
        float inv_det = 1.0f / det;
        
        mat3 result;
        result(0,0) = ((*this)(1,1)*(*this)(2,2) - (*this)(1,2)*(*this)(2,1)) * inv_det;
        result(0,1) = ((*this)(0,2)*(*this)(2,1) - (*this)(0,1)*(*this)(2,2)) * inv_det;
        result(0,2) = ((*this)(0,1)*(*this)(1,2) - (*this)(0,2)*(*this)(1,1)) * inv_det;
        
        result(1,0) = ((*this)(1,2)*(*this)(2,0) - (*this)(1,0)*(*this)(2,2)) * inv_det;
        result(1,1) = ((*this)(0,0)*(*this)(2,2) - (*this)(0,2)*(*this)(2,0)) * inv_det;
        result(1,2) = ((*this)(0,2)*(*this)(1,0) - (*this)(0,0)*(*this)(1,2)) * inv_det;
        
        result(2,0) = ((*this)(1,0)*(*this)(2,1) - (*this)(1,1)*(*this)(2,0)) * inv_det;
        result(2,1) = ((*this)(0,1)*(*this)(2,0) - (*this)(0,0)*(*this)(2,1)) * inv_det;
        result(2,2) = ((*this)(0,0)*(*this)(1,1) - (*this)(0,1)*(*this)(1,0)) * inv_det;
        
        return result;
    }
    
    // 调试输出
    void print(const std::string& name = "") const {
        if (!name.empty()) {
            std::cout << name << " = " << std::endl;
        }
        std::cout << std::fixed << std::setprecision(4);
        for (int i = 0; i < 3; ++i) {
            std::cout << "[ ";
            for (int j = 0; j < 3; ++j) {
                std::cout << std::setw(8) << (*this)(i, j) << " ";
            }
            std::cout << "]" << std::endl;
        }
    }
    
    // GLSL风格静态构造函数
    static mat3 identity() { return mat3(); }
    
    static mat3 zeros() { return mat3(0.0f); }
    
    // 创建缩放矩阵
    static mat3 scale(float sx, float sy) {
        return mat3(sx, 0.0f, 0.0f,
                    0.0f, sy, 0.0f,
                    0.0f, 0.0f, 1.0f);
    }
    
    // 创建旋转矩阵（绕Z轴，GLSL风格）
    static mat3 rotate(float angle_radians) {
        float c = std::cos(angle_radians);
        float s = std::sin(angle_radians);
        return mat3(c, s, 0.0f,
                    -s, c, 0.0f,
                    0.0f, 0.0f, 1.0f);
    }
    
    // 创建平移矩阵（3x3齐次坐标下的平移）
    static mat3 translate(float tx, float ty) {
        return mat3(1.0f, 0.0f, 0.0f,
                    0.0f, 1.0f, 0.0f,
                    tx, ty, 1.0f);
    }
};

inline mat3 transpose(mat3 m)
{
    return m.transpose();
}

#endif