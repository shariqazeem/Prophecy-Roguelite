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

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;

    // Subtle animated gradient
    float n1 = noise(uv * 3.0 + vec2(t * 0.2, t * 0.15));
    float n2 = noise(uv * 6.0 + vec2(-t * 0.1, t * 0.08));
    float pattern = n1 * 0.6 + n2 * 0.4;

    // Market phase palettes (dark terminal aesthetic)
    // 0: Bull Market (dark green-tinted)
    vec3 base0 = vec3(0.06, 0.08, 0.06);
    vec3 accent0 = vec3(0.08, 0.15, 0.08);
    // 1: Sideways (dark neutral)
    vec3 base1 = vec3(0.07, 0.07, 0.09);
    vec3 accent1 = vec3(0.10, 0.10, 0.14);
    // 2: Bear Market (dark red-tinted)
    vec3 base2 = vec3(0.09, 0.06, 0.06);
    vec3 accent2 = vec3(0.15, 0.08, 0.08);
    // 3: Capitulation (very dark)
    vec3 base3 = vec3(0.04, 0.03, 0.06);
    vec3 accent3 = vec3(0.08, 0.05, 0.10);

    // Interpolate between market phases
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

    // Vignette — stronger at deeper phases
    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * (0.3 + biome * 0.15);
    col *= vignette;

    // Very subtle moving highlight
    float highlight = smoothstep(0.55, 0.45, length(uv - vec2(0.5 + sin(t) * 0.1, 0.4 + cos(t * 0.7) * 0.05)));
    float highlight_strength = max(0.02 - biome * 0.004, 0.005);
    col += vec3(highlight_strength * 0.5, highlight_strength * 0.75, highlight_strength * 1.2) * highlight;

    // Capitulation particles (red/orange instead of purple)
    if (biome > 2.0) {
        float particle_intensity = (biome - 2.0);
        float p1 = noise(uv * 20.0 + vec2(t * 0.5, t * 0.3));
        float p2 = noise(uv * 30.0 + vec2(-t * 0.4, t * 0.6));
        float particles = smoothstep(0.75, 0.85, p1) + smoothstep(0.78, 0.88, p2);
        col += vec3(0.6, 0.3, 0.15) * particles * 0.15 * particle_intensity;
    }

    COLOR = vec4(col, 1.0);
}
