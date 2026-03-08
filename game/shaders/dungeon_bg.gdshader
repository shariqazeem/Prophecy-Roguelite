shader_type canvas_item;

uniform float time_speed : hint_range(0.01, 1.0) = 0.08;
uniform float biome : hint_range(0.0, 3.0) = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise(p);
        p *= 2.2;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;

    // 3-octave FBM nebula swirls
    float n1 = fbm(uv * 3.0 + vec2(t * 0.2, t * 0.15));
    float n2 = fbm(uv * 5.0 + vec2(-t * 0.15, t * 0.1));
    float pattern = n1 * 0.6 + n2 * 0.4;

    // Obsidian dark palettes
    // 0: Void (deep blue-black)
    vec3 base0 = vec3(0.03, 0.03, 0.06);
    vec3 accent0 = vec3(0.06, 0.06, 0.12);
    // 1: Nebula (purple-tinted dark)
    vec3 base1 = vec3(0.04, 0.03, 0.07);
    vec3 accent1 = vec3(0.08, 0.06, 0.14);
    // 2: Crimson Rift (dark red-purple)
    vec3 base2 = vec3(0.06, 0.03, 0.05);
    vec3 accent2 = vec3(0.12, 0.05, 0.10);
    // 3: Abyss (near-black)
    vec3 base3 = vec3(0.02, 0.02, 0.04);
    vec3 accent3 = vec3(0.05, 0.03, 0.08);

    // Interpolate between biome phases
    vec3 base_color;
    vec3 accent_color;
    if (biome < 1.0) {
        base_color = mix(base0, base1, biome);
        accent_color = mix(accent0, accent1, biome);
    } else if (biome < 2.0) {
        base_color = mix(base1, base2, biome - 1.0);
        accent_color = mix(accent1, accent2, biome - 1.0);
    } else {
        base_color = mix(base2, base3, clamp(biome - 2.0, 0.0, 1.0));
        accent_color = mix(accent2, accent3, clamp(biome - 2.0, 0.0, 1.0));
    }

    vec3 col = mix(base_color, accent_color, pattern * 0.5);

    // Purple void particle drift (all biome levels)
    float p1 = noise(uv * 15.0 + vec2(t * 0.4, t * 0.25));
    float p2 = noise(uv * 25.0 + vec2(-t * 0.3, t * 0.5));
    float particles = smoothstep(0.72, 0.85, p1) + smoothstep(0.76, 0.88, p2);
    col += vec3(0.25, 0.15, 0.45) * particles * 0.08 * (0.5 + biome * 0.2);

    // Subtle purple moving highlight
    float highlight = smoothstep(0.55, 0.45, length(uv - vec2(0.5 + sin(t) * 0.1, 0.4 + cos(t * 0.7) * 0.05)));
    float highlight_strength = max(0.02 - biome * 0.004, 0.005);
    col += vec3(highlight_strength * 0.6, highlight_strength * 0.3, highlight_strength * 1.4) * highlight;

    // Heavier vignette
    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * (0.5 + biome * 0.2);
    col *= vignette;

    // Film grain
    float grain = hash(uv * 300.0 + vec2(TIME * 7.0, TIME * 11.0)) * 0.06 - 0.03;
    col += grain;

    // Extra particles at high biome (abyss)
    if (biome > 2.0) {
        float intensity = (biome - 2.0);
        float p3 = noise(uv * 35.0 + vec2(t * 0.6, t * 0.35));
        float deep_particles = smoothstep(0.78, 0.9, p3);
        col += vec3(0.4, 0.1, 0.3) * deep_particles * 0.15 * intensity;
    }

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
