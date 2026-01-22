#pragma once

#include <iostream>
#include <cmath>
#include <string>
#include <sstream>
#include <iomanip>

// ==================== ivec2 类 ====================
class ivec2 {
public:
    int x, y;
    

    // 构造函数
    ivec2() : x(0), y(0) {}
    ivec2(int v) : x(v), y(v) {}
    ivec2(int x, int y) : x(x), y(y) {}
    ivec2(float x, int y) : x((int)x), y(y) {}

    // 从浮点数构造（显式转换）
    explicit ivec2(float x, float y) : x(static_cast<int>(x)), y(static_cast<int>(y)) {}
    
    // 获取分量
    int getX() const { return x; }
    int getY() const { return y; }
    
    // 设置分量
    void setX(int val) { x = val; }
    void setY(int val) { y = val; }
    
    // 数组式访问
    int& operator[](int index) {
        if (index == 0) return x;
        if (index == 1) return y;
        throw std::out_of_range("ivec2 index out of range");
    }
    
    const int& operator[](int index) const {
        if (index == 0) return x;
        if (index == 1) return y;
        throw std::out_of_range("ivec2 index out of range");
    }
    
    // 算术运算
    ivec2 operator+(const ivec2& other) const {
        return ivec2(x + other.x, y + other.y);
    }
    
    ivec2 operator-(const ivec2& other) const {
        return ivec2(x - other.x, y - other.y);
    }
    
    ivec2 operator*(const ivec2& other) const {
        return ivec2(x * other.x, y * other.y);
    }
    
    ivec2 operator/(const ivec2& other) const {
        return ivec2(x / other.x, y / other.y);
    }
    
    ivec2 operator%(const ivec2& other) const {
        return ivec2(x % other.x, y % other.y);
    }
    
    // 标量运算
    ivec2 operator+(int scalar) const {
        return ivec2(x + scalar, y + scalar);
    }
    
    ivec2 operator-(int scalar) const {
        return ivec2(x - scalar, y - scalar);
    }
    
    ivec2 operator*(int scalar) const {
        return ivec2(x * scalar, y * scalar);
    }
    
    ivec2 operator/(int scalar) const {
        return ivec2(x / scalar, y / scalar);
    }
    
    ivec2 operator%(int scalar) const {
        return ivec2(x % scalar, y % scalar);
    }
    
    friend ivec2 operator+(int scalar, const ivec2& vec) {
        return vec + scalar;
    }
    
    friend ivec2 operator*(int scalar, const ivec2& vec) {
        return vec * scalar;
    }
    
    // 复合赋值运算
    ivec2& operator+=(const ivec2& other) {
        x += other.x;
        y += other.y;
        return *this;
    }
    
    ivec2& operator-=(const ivec2& other) {
        x -= other.x;
        y -= other.y;
        return *this;
    }
    
    ivec2& operator*=(const ivec2& other) {
        x *= other.x;
        y *= other.y;
        return *this;
    }
    
    ivec2& operator/=(const ivec2& other) {
        x /= other.x;
        y /= other.y;
        return *this;
    }
    
    ivec2& operator%=(const ivec2& other) {
        x %= other.x;
        y %= other.y;
        return *this;
    }
    
    // 关系运算
    bool operator==(const ivec2& other) const {
        return x == other.x && y == other.y;
    }
    
    bool operator!=(const ivec2& other) const {
        return !(*this == other);
    }
    
    // 位运算
    ivec2 operator&(const ivec2& other) const {
        return ivec2(x & other.x, y & other.y);
    }
    
    ivec2 operator|(const ivec2& other) const {
        return ivec2(x | other.x, y | other.y);
    }
    
    ivec2 operator^(const ivec2& other) const {
        return ivec2(x ^ other.x, y ^ other.y);
    }
    
    ivec2 operator<<(const ivec2& other) const {
        return ivec2(x << other.x, y << other.y);
    }
    
    ivec2 operator>>(const ivec2& other) const {
        return ivec2(x >> other.x, y >> other.y);
    }
    
    ivec2 operator~() const {
        return ivec2(~x, ~y);
    }
    
    // 标量位运算
    ivec2 operator&(int scalar) const {
        return ivec2(x & scalar, y & scalar);
    }
    
    ivec2 operator|(int scalar) const {
        return ivec2(x | scalar, y | scalar);
    }
    
    ivec2 operator^(int scalar) const {
        return ivec2(x ^ scalar, y ^ scalar);
    }
    
    ivec2 operator<<(int scalar) const {
        return ivec2(x << scalar, y << scalar);
    }
    
    ivec2 operator>>(int scalar) const {
        return ivec2(x >> scalar, y >> scalar);
    }
    
    // 常用函数
    int dot(const ivec2& other) const {
        return x * other.x + y * other.y;
    }
    
    float length() const {
        return std::sqrt(static_cast<float>(x * x + y * y));
    }
    
    int lengthSquared() const {
        return x * x + y * y;
    }
    
    float distance(const ivec2& other) const {
        return (*this - other).length();
    }
    
    int distanceSquared(const ivec2& other) const {
        return (*this - other).lengthSquared();
    }
    
    ivec2 abs() const {
        return ivec2(std::abs(x), std::abs(y));
    }
    
    ivec2 sign() const {
        return ivec2(
            (x > 0) ? 1 : (x < 0 ? -1 : 0),
            (y > 0) ? 1 : (y < 0 ? -1 : 0)
        );
    }
    
    ivec2 min(const ivec2& other) const {
        return ivec2(
            std::min(x, other.x),
            std::min(y, other.y)
        );
    }
    
    ivec2 max(const ivec2& other) const {
        return ivec2(
            std::max(x, other.x),
            std::max(y, other.y)
        );
    }
    
    ivec2 clamp(const ivec2& minVal, const ivec2& maxVal) const {
        return this->max(minVal).min(maxVal);
    }
    
    // GLSL风格静态函数
    static ivec2 zero() { return ivec2(0, 0); }
    static ivec2 one() { return ivec2(1, 1); }
    static ivec2 up() { return ivec2(0, 1); }
    static ivec2 down() { return ivec2(0, -1); }
    static ivec2 left() { return ivec2(-1, 0); }
    static ivec2 right() { return ivec2(1, 0); }
    
    // 调试输出
    void print(const std::string& name = "") const {
        if (!name.empty()) {
            std::cout << name << " = ";
        }
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
    
    std::string to_string() const {
        std::stringstream ss;
        ss << "(" << x << ", " << y << ")";
        return ss.str();
    }
    
    // 类型转换操作符
    operator bool() const {
        return x != 0 || y != 0;
    }
};

// ==================== 类型转换函数 ====================
class vec2 {
public:
    float x, y;
    

    vec2(float x = 0, float y = 0) : x(x), y(y) {}
    
    float getX() const { return x; }
    float getY() const { return y; }
    
    // 从 ivec2 隐式转换
    vec2(const ivec2& iv) : x(static_cast<float>(iv.getX())), y(static_cast<float>(iv.getY())) {}
    
    void print(const std::string& name = "") const {
        if (!name.empty()) {
            std::cout << name << " = ";
        }
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

// GLSL风格类型转换函数
inline ivec2 ivec2_cast(const vec2& v) {
    return ivec2(static_cast<int>(v.getX()), static_cast<int>(v.getY()));
}

inline ivec2 ivec2_cast(float x, float y) {
    return ivec2(static_cast<int>(x), static_cast<int>(y));
}

// GLSL风格函数（针对 ivec2）
inline ivec2 abs(const ivec2& v) {
    return v.abs();
}

inline ivec2 sign(const ivec2& v) {
    return v.sign();
}

inline ivec2 min(const ivec2& a, const ivec2& b) {
    return a.min(b);
}

inline ivec2 max(const ivec2& a, const ivec2& b) {
    return a.max(b);
}

inline ivec2 clamp(const ivec2& v, const ivec2& minVal, const ivec2& maxVal) {
    return v.clamp(minVal, maxVal);
}

inline int dot(const ivec2& a, const ivec2& b) {
    return a.dot(b);
}

inline float length(const ivec2& v) {
    return v.length();
}

inline int lengthSquared(const ivec2& v) {
    return v.lengthSquared();
}

inline float distance(const ivec2& a, const ivec2& b) {
    return a.distance(b);
}

inline int distanceSquared(const ivec2& a, const ivec2& b) {
    return a.distanceSquared(b);
}

// ==================== 更多 GLSL 风格函数 ====================
// 混合函数（线性插值）
inline ivec2 mix(const ivec2& x, const ivec2& y, float a) {
    return ivec2(
        static_cast<int>(x.getX() * (1.0f - a) + y.getX() * a),
        static_cast<int>(x.getY() * (1.0f - a) + y.getY() * a)
    );
}

inline ivec2 mix(const ivec2& x, const ivec2& y, const ivec2& a) {
    return ivec2(
        static_cast<int>(x.getX() * (1.0f - a.getX()) + y.getX() * a.getX()),
        static_cast<int>(x.getY() * (1.0f - a.getY()) + y.getY() * a.getY())
    );
}

// 步进函数
inline ivec2 step(const ivec2& edge, const ivec2& x) {
    return ivec2(
        x.getX() >= edge.getX() ? 1 : 0,
        x.getY() >= edge.getY() ? 1 : 0
    );
}

inline ivec2 step(int edge, const ivec2& x) {
    return ivec2(
        x.getX() >= edge ? 1 : 0,
        x.getY() >= edge ? 1 : 0
    );
}

// 平滑步进函数（整数版本简化）
inline ivec2 smoothstep(const ivec2& edge0, const ivec2& edge1, const ivec2& x) {
    ivec2 t = clamp((x - edge0) / (edge1 - edge0), ivec2::zero(), ivec2::one());
    return t * t * (ivec2(3) - ivec2(2) * t);
}

// ==================== 运算符重载（全局） ====================
inline std::ostream& operator<<(std::ostream& os, const ivec2& v) {
    os << "(" << v.getX() << ", " << v.getY() << ")";
    return os;
}

