#version 440

// Live Liquid Glass fragment shader with true compositor transparency.
// Designed for Wayland layershell with compositor-level blur (Hyprland Dual Kawase).
// Zero static wallpaper sampling — adapts live to whatever window is behind it!
// Completely borderless (no harsh contours or outlines), ultra-translucent frosted glass.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;              // widget size in px
    float radius;            // corner radius in px
    float roundness;         // superellipse exponent; 2 = circle, 5 ≈ iOS squircle, 7.5 = liquid squircle
    float refractThickness;  // edge band width in px
    float refractIOR;
    float refractScale;
    float chromaStrength;    // 0..1 chromatic aberration
    vec4  tint;              // subtle white frost tint
    vec4  tintBottom;        // bottom tint
    vec2  uvOffset;
    vec2  uvScale;
    vec2  mousePos;          // widget-local UV (0..1); (-1,-1) = no mouse
    float mouseFade;         // 0..1 hover fade
    float specStrength;      // 0..1 intensity
    vec4  overlayDarken;     // dark base
};

// Squircle / rounded-box SDF with analytic gradient.
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

// Interactive cursor specular (ONLY active when hovering, completely absent at rest)
vec3 hoverSpec(vec2 p, float depthPx) {
    if (specStrength <= 0.0 || mouseFade <= 0.001 || mousePos.x < 0.0 || mousePos.y < 0.0) {
        return vec3(0.0);
    }

    const float MAX_STROKE_PX = 2.0;
    const float FEATHER_PX    = 2.0;

    vec2 b = size * 0.5;
    vec2 cursorPx = (mousePos - vec2(0.5)) * size;

    float taper = max(size.x, size.y) * 0.6;
    float att   = exp(-distance(p, cursorPx) / taper);

    float tPx = att * MAX_STROKE_PX;
    float stroke = 1.0 - smoothstep(0.0, tPx + FEATHER_PX, depthPx);

    float I = stroke * att * specStrength * mouseFade * 0.40;
    return vec3(1.0, 0.98, 0.95) * I;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p  = (uv - vec2(0.5)) * size;
    vec3 dn = sceneSDFAndNormal(p);
    float d = dn.x;

    // Outside the shape: fully transparent
    if (d > 1.5) {
        fragColor = vec4(0.0);
        return;
    }

    float depthPx = -d;

    // Base glass colors: ultra-translucent
    vec3 darkBase = overlayDarken.rgb;
    float darkAlpha = overlayDarken.a;

    vec3 frostTint = mix(tint.rgb, tintBottom.rgb, tintBottom.a > 0.0 ? uv.y : 0.0);
    float frostAlpha = tint.a;

    // Smooth, uniform translucent glass body (ZERO contours, zero harsh outlines)
    float totalAlphaSum = max(0.0001, darkAlpha + frostAlpha);
    vec3 glassColor = mix(darkBase, frostTint, frostAlpha / totalAlphaSum);
    float glassAlpha = clamp(darkAlpha + frostAlpha, 0.0, 1.0);

    // Subtle hover-only light glint (zero at rest)
    vec3 cHover = hoverSpec(p, depthPx);
    glassColor += cHover;

    float finalAlpha = clamp(glassAlpha + cHover.r * 0.20, 0.0, 1.0);

    // Subpixel SDF anti-aliasing mask at the geometric boundary
    float mask = 1.0 - smoothstep(-0.5, 0.5, d);

    // Premultiplied alpha output for Qt Quick scene graph
    fragColor = vec4(glassColor * finalAlpha * mask, finalAlpha * mask) * qt_Opacity;
}
