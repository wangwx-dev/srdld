shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 subject_screen_uv = vec2(0.5, 0.5);
uniform float subject_view_depth = 10.0;
uniform float radius_pixels : hint_range(20.0, 400.0) = 150.0;
uniform float removed_coverage : hint_range(0.0, 1.0) = 0.75;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.32;
uniform bool enabled = true;
const float BAYER[16] = float[16](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
void fragment() {
    vec2 pixel_delta = (SCREEN_UV - subject_screen_uv) * VIEWPORT_SIZE;
    float r = length(pixel_delta);
    // Only occluder fragments closer than the subject are cut; surfaces behind remain intact.
    bool in_front = -VERTEX.z < subject_view_depth - 0.08;
    if (enabled && in_front && r < radius_pixels) {
        ivec2 p = ivec2(FRAGCOORD.xy) % 4;
        float threshold = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
        // Feather only the last 8px; coverage is binary discard, not sorted transparency.
        float edge = 1.0 - smoothstep(radius_pixels - 8.0, radius_pixels, r);
        if (threshold < removed_coverage * edge) { discard; }
    }
    ALBEDO = texture(albedo_tex, UV).rgb;
    ROUGHNESS = texture(roughness_tex, UV).r;
    NORMAL_MAP = texture(normal_tex, UV).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
}
