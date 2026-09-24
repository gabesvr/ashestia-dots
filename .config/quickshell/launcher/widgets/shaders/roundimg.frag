#version 440
// Recorte arredondado com borda suavizada (AlbumArt). Distância até um retângulo arredondado
// + smoothstep de ~1 px: canto liso em qualquer escala, sem os degraus da máscara do MultiEffect.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
};
layout(binding = 1) uniform sampler2D source;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    float d = sdRoundBox(p, itemSize * 0.5, min(radius, min(itemSize.x, itemSize.y) * 0.5));
    float aa = max(fwidth(d), 0.5);
    float a = 1.0 - smoothstep(-aa, aa, d);
    fragColor = texture(source, qt_TexCoord0) * a * qt_Opacity;
}
