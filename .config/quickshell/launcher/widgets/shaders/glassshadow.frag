#version 440

// Sombra suave e difusa do vidro (desenhada num retângulo maior que o widget)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;        // tamanho do widget
    float pad;         // margem extra em cada lado
    float radius;
    float roundness;
    float blur;        // largura da penumbra
    float strength;    // 0..1
    float offsetY;     // deslocamento vertical da sombra
};

float sdf(vec2 p) {
    vec2 b = size * 0.5;
    float n = max(roundness, 2.0);
    float r = clamp(radius, 0.0, min(b.x, b.y));
    vec2 q = abs(p) - b + vec2(r);
    vec2 qp = max(q, vec2(0.0));
    float outside = pow(pow(qp.x, n) + pow(qp.y, n), 1.0 / n);
    return min(max(q.x, q.y), 0.0) + outside - r;
}

void main() {
    vec2 full = size + vec2(2.0 * pad);
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * full - vec2(0.0, offsetY);
    float d = sdf(p);
    float a = strength * (1.0 - smoothstep(-blur * 0.15, blur, d));
    a *= a * 0.6 + 0.4;                       // cauda mais macia
    fragColor = vec4(0.0, 0.0, 0.02, 1.0) * (a * qt_Opacity);
}
