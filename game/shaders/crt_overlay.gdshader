shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - 0.5;
    float dist_sq = dot(center, center);

    // Barrel distortion (subtle screen curvature)
    vec2 curved = uv + center * dist_sq * 0.025;

    // Chromatic aberration — stronger at edges
    float ab = dist_sq * 0.008;
    float r = texture(screen_tex, curved + vec2(ab, 0.0)).r;
    float g = texture(screen_tex, curved).g;
    float b = texture(screen_tex, curved - vec2(ab, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // High-frequency scanlines
    float scan = sin(curved.y * 700.0) * 0.5 + 0.5;
    col *= 1.0 - scan * 0.04;

    // Slow vertical scan beam (bright band sweeping down)
    float beam_y = fract(TIME * 0.06);
    float beam_d = abs(curved.y - beam_y);
    beam_d = min(beam_d, 1.0 - beam_d);
    col += smoothstep(0.08, 0.0, beam_d) * 0.05;

    // Subtle horizontal noise flicker
    float flicker = fract(sin(dot(vec2(TIME * 13.0, curved.y * 100.0), vec2(12.9898, 78.233))) * 43758.5453);
    col += (flicker - 0.5) * 0.008;

    // CRT edge vignette
    col *= 1.0 - dist_sq * 0.5;

    COLOR = vec4(col, 1.0);
}
