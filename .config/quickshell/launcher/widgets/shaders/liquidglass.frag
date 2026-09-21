#version 440

// Liquid Glass (Snell-on-a-dome refraction) + limitador de brilho do backdrop.
// lumaCap >= 1.0 desativa o limitador (comportamento original).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;
    float radius;
    float roundness;
    float refractThickness;
    float refractIOR;
    float refractScale;
    float chromaStrength;
    vec4  tint;
    vec4  tintBottom;
    vec2  uvOffset;
    vec2  uvScale;
    vec2  mousePos;
    float mouseFade;
    float specStrength;
    vec4  overlayDarken;
    float lumaCap;
    vec4  style;   // x=saturation  y=rim light  z=top sheen  w=inner depth shade
    float solidT;  // 0 = vidro líquido, 1 = superfície sólida cinza-escura
};

layout(binding = 1) uniform sampler2D backdrop;

vec3 sceneSDFAndNormal(vec2 p) {
    vec2 b = size * 0.5;
    float n = max(roundness, 2.0);
    float r = clamp(radius, 0.0, min(b.x, b.y));

    vec2 q = abs(p) - b + vec2(r);
    float qx = max(q.x, 0.0);
    float qy = max(q.y, 0.0);

    float d;
    vec2 nrm;

    if (qx <= 0.0 && qy <= 0.0) {
        d = max(q.x, q.y) - r;
        nrm = q.x >= q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    } else if (qx == 0.0) {
        d = qy - r;
        nrm = vec2(0.0, 1.0);
    } else if (qy == 0.0) {
        d = qx - r;
        nrm = vec2(1.0, 0.0);
    } else {
        float qxn = pow(qx, n);
        float qyn = pow(qy, n);
        float arc = pow(qxn + qyn, 1.0 / n);
        float gx = pow(qx / arc, n - 1.0);
        float gy = pow(qy / arc, n - 1.0);
        float gradLen = sqrt(gx * gx + gy * gy);
        d   = (arc - r) / max(gradLen, 1e-3);
        nrm = vec2(gx, gy) / max(gradLen, 1e-3);
    }

    nrm *= sign(p + vec2(1e-20));
    return vec3(d, nrm);
}

// Comprime só as altas luzes (nuvens brancas etc.) mantendo matiz e o resto da imagem
vec3 tameHighlights(vec3 c) {
    if (lumaCap >= 1.0) return c;
    float L = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float knee = lumaCap * 0.55;
    if (L <= knee) return c;
    float x = clamp((L - knee) / max(1.0 - knee, 1e-3), 0.0, 1.0);
    float k = 2.5;
    float t = (1.0 - exp(-k * x)) / (1.0 - exp(-k));
    float Lt = knee + (lumaCap - knee) * t;
    return c * (Lt / max(L, 1e-4));
}

vec3 sampleBackdrop(vec2 localUV) {
    vec2 wpUV = clamp(uvOffset + localUV * uvScale, vec2(0.0), vec2(1.0));
    vec3 c = texture(backdrop, wpUV).rgb;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, style.x);          // vibrancy do vidro
    return tameHighlights(max(c, vec3(0.0)));
}

// Luz vem do canto superior esquerdo; segundo lóbulo mais fraco no canto oposto (como o vidro real)
float rimLobe(vec2 ndir) {
    vec2 L = normalize(vec2(-0.62, -0.78));
    float a = pow(max(dot(ndir, L), 0.0), 1.6);
    float b = pow(max(dot(ndir, -L), 0.0), 1.6) * 0.55;
    return clamp(0.34 + 0.75 * (a + b), 0.0, 1.0);
}

vec3 rimLight(vec2 ndir, float depthPx) {
    if (specStrength <= 0.0) return vec3(0.0);
    float lobe = rimLobe(ndir);
    float line = 1.0 - smoothstep(0.35, 1.5, max(depthPx, 0.0));       // fio nítido de ~1.2px
    float glow = exp(-max(depthPx, 0.0) / 7.0);                         // brilho interno suave
    float I = (line * 0.55 + glow * 0.07) * lobe * style.y * specStrength;
    return vec3(1.0, 0.985, 0.96) * I;
}

vec3 cornerSpec(vec2 p, float depthPx) {
    if (specStrength <= 0.0) return vec3(0.0);
    vec2 b = size * 0.5;
    vec2 restLight = vec2(-b.x, b.y) * 1.2;
    bool hovering = mouseFade > 0.0 && mousePos.x >= 0.0 && mousePos.y >= 0.0;
    vec2 cursorPx = (mousePos - vec2(0.5)) * size;
    vec2 lightPx = hovering ? mix(restLight, cursorPx, mouseFade) : restLight;
    vec2 antiLight = -lightPx;

    float taper = max(size.x, size.y) * 0.7;
    float primaryAtt   = exp(-distance(p, lightPx) / taper);
    float secondaryAtt = exp(-distance(p, antiLight) / taper) * 0.65;
    float tPx = max(primaryAtt, secondaryAtt) * 3.0;
    float stroke = 1.0 - smoothstep(tPx - 2.0, tPx, depthPx);
    float I = stroke * specStrength * 0.55;
    return vec3(1.0, 0.98, 0.94) * I;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p  = (uv - vec2(0.5)) * size;
    vec3 dn = sceneSDFAndNormal(p);
    float d = dn.x;
    vec2 ndir = dn.yz;

    if (d > 1.5) {
        fragColor = vec4(0.0);
        return;
    }

    float depthPx = -d;
    bool canRefract = refractThickness > 0.0;

    vec3 tintColor = mix(tint.rgb, tintBottom.rgb, tintBottom.a > 0.0 ? uv.y : 0.0);
    float tintA = tint.a;

    vec3 col;
    if (!canRefract || depthPx >= refractThickness) {
        col = sampleBackdrop(uv);
        col = mix(col, tintColor, tintA);
    } else {
        float t = clamp(depthPx / refractThickness, 0.0, 1.0);
        float sinThetaI = (1.0 - t) * (1.0 - t);
        float thetaI = asin(clamp(sinThetaI, 0.0, 1.0));
        float sinThetaT = sinThetaI / refractIOR;
        float thetaT = asin(clamp(sinThetaT, 0.0, 1.0));
        float edgeMag = tan(thetaI - thetaT);

        vec2 displacePx = -ndir * edgeMag * refractScale;
        vec2 displaceUV = displacePx / size;

        float edgeWeight = 1.0 - t;
        float chromaPx = chromaStrength * refractThickness * 0.35 * edgeWeight;
        vec2 chromaUV = (-ndir * chromaPx) / size;

        col.r = sampleBackdrop(uv + displaceUV + chromaUV).r;
        col.g = sampleBackdrop(uv + displaceUV).g;
        col.b = sampleBackdrop(uv + displaceUV - chromaUV).b;
        col = mix(col, tintColor, tintA);
    }

    // Escurecimento adaptativo (preserva o matiz do fundo): fundo claro -> vidro um pouco mais denso, texto branco legível
    float Lc = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, col * 0.60, smoothstep(0.50, 0.90, Lc) * 0.65 * step(lumaCap, 0.999));

    if (overlayDarken.a > 0.0) {
        float darkenT = smoothstep(1.0 - overlayDarken.a, 1.0, uv.y);
        col = mix(col, overlayDarken.rgb, darkenT);
    }

    // Modo sólido: mistura para o cinza-escuro do terminal (#2b2d33)
    col = mix(col, vec3(0.1686, 0.1765, 0.2), solidT);
    float gk = 1.0 - solidT;

    // Profundidade: leve sombra interna no lado oposto à luz
    float lobeOpp = pow(max(dot(ndir, normalize(vec2(0.55, 0.83))), 0.0), 1.4);
    col *= 1.0 - style.w * 0.22 * exp(-max(depthPx, 0.0) / 9.0) * lobeOpp * gk;

    // Brilho suave de topo (sheen)
    col += vec3(1.0) * style.z * 0.075 * pow(1.0 - uv.y, 2.2) * gk;

    col += rimLight(ndir, depthPx) * gk;
    col += cornerSpec(p, depthPx) * gk;

    // Contorno sutil no modo sólido
    col += vec3(1.0) * solidT * 0.07 * (1.0 - smoothstep(0.3, 1.3, max(depthPx, 0.0)));

    float mask = 1.0 - smoothstep(-0.5, 0.5, d);
    fragColor = vec4(col * mask, mask) * qt_Opacity;
}
