#version 320 es

// Nen — Audio Visualizer Fragment Shader
// Receives frequency band data as uniforms and renders a reactive visualization.
// Designed for Flutter's Impeller engine (AOT-compiled, 60–120 FPS).

precision highp float;

// Flutter-provided uniforms
layout(location = 0) uniform vec2 uSize;       // Canvas size in pixels
layout(location = 1) uniform float uTime;      // Elapsed time in seconds

// Frequency band uniforms (0.0–1.0 normalized)
layout(location = 2) uniform float uSubBass;    // 20–60 Hz
layout(location = 3) uniform float uBass;       // 60–250 Hz
layout(location = 4) uniform float uLowMid;     // 250–500 Hz
layout(location = 5) uniform float uMid;        // 500–2000 Hz
layout(location = 6) uniform float uUpperMid;   // 2000–4000 Hz
layout(location = 7) uniform float uPresence;   // 4000–6000 Hz
layout(location = 8) uniform float uBrilliance; // 6000–20000 Hz

// Accent color from album art
layout(location = 9) uniform vec3 uAccentColor;

// Reduce motion / flash flags (1.0 = reduce, 0.0 = normal)
layout(location = 10) uniform float uReduceMotion;

layout(location = 0) out vec4 fragColor;

// ── Helpers ─────────────────────────────────────────────────────────

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        val += amp * noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return val;
}

// ── Main ────────────────────────────────────────────────────────────

void main() {
    vec2 uv = gl_FragCoord.xy / uSize;
    vec2 centered = (gl_FragCoord.xy - 0.5 * uSize) / min(uSize.x, uSize.y);

    float time = uReduceMotion > 0.5 ? uTime * 0.15 : uTime;

    // Distance from center
    float dist = length(centered);
    float angle = atan(centered.y, centered.x);

    // ── Background: deep dark with subtle noise ──
    float bgNoise = fbm(uv * 3.0 + time * 0.05) * 0.04;
    vec3 bg = vec3(bgNoise);

    // ── Central orb reacting to sub-bass and bass ──
    float orbRadius = 0.12 + uSubBass * 0.08 + uBass * 0.06;
    float orbPulse = sin(time * 2.0) * 0.01 * (1.0 - uReduceMotion);
    orbRadius += orbPulse;

    float orbGlow = smoothstep(orbRadius + 0.15, orbRadius, dist);
    float orbCore = smoothstep(orbRadius + 0.02, orbRadius - 0.02, dist);

    vec3 orbColor = uAccentColor * (0.6 + uBass * 0.4);
    vec3 glowColor = uAccentColor * 0.3;

    // ── Radial frequency bands as concentric rings ──
    float bands[7];
    bands[0] = uSubBass;
    bands[1] = uBass;
    bands[2] = uLowMid;
    bands[3] = uMid;
    bands[4] = uUpperMid;
    bands[5] = uPresence;
    bands[6] = uBrilliance;

    vec3 ringAccum = vec3(0.0);
    for (int i = 0; i < 7; i++) {
        float bandRadius = 0.2 + float(i) * 0.065;
        float bandWidth = 0.008 + bands[i] * 0.025;

        // Add angular distortion based on band energy
        float angularWarp = sin(angle * (3.0 + float(i)) + time * (0.5 + float(i) * 0.1))
                          * bands[i] * 0.03
                          * (1.0 - uReduceMotion * 0.7);
        float d = abs(dist - bandRadius - angularWarp) - bandWidth;
        float ring = smoothstep(0.015, 0.0, d);

        // Color gradient across bands: from accent to complement
        float hueShift = float(i) / 7.0;
        vec3 bandColor = mix(
            uAccentColor,
            vec3(uAccentColor.z, uAccentColor.x, uAccentColor.y),
            hueShift
        );
        bandColor *= (0.4 + bands[i] * 0.6);

        ringAccum += ring * bandColor * (0.5 + bands[i] * 0.5);
    }

    // ── Particle field responding to highs ──
    float particles = 0.0;
    if (uReduceMotion < 0.5) {
        for (int i = 0; i < 20; i++) {
            vec2 pPos = vec2(
                hash(vec2(float(i), 1.0)),
                hash(vec2(1.0, float(i)))
            ) - 0.5;
            pPos *= 1.8;

            float pTime = time * (0.2 + hash(vec2(float(i), 3.0)) * 0.3);
            pPos.x += sin(pTime) * 0.1;
            pPos.y += cos(pTime * 1.3) * 0.1;

            float pDist = length(centered - pPos);
            float pSize = 0.003 + uBrilliance * 0.004 + uPresence * 0.002;
            particles += smoothstep(pSize + 0.005, pSize, pDist)
                       * (0.3 + uBrilliance * 0.7);
        }
    }

    vec3 particleColor = mix(vec3(1.0), uAccentColor, 0.3) * particles;

    // ── Compose ──
    vec3 color = bg;
    color += glowColor * orbGlow;
    color += orbColor * orbCore;
    color += ringAccum;
    color += particleColor;

    // Subtle vignette
    float vignette = 1.0 - smoothstep(0.4, 1.1, dist);
    color *= vignette;

    // Clamp output — no strobing (WCAG compliance)
    color = clamp(color, vec3(0.0), vec3(1.0));

    fragColor = vec4(color, 1.0);
}
