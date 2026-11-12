shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D shell_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D bed_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D bed_z : filter_linear, repeat_disable;
uniform sampler2D shelf_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D shelf_z : filter_linear, repeat_disable;
uniform sampler2D chair_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D chair_z : filter_linear, repeat_disable;
uniform sampler2D desk_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D desk_z : filter_linear, repeat_disable;
uniform sampler2D char_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D char_z : filter_linear, repeat_disable;
uniform sampler2D cat_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D cat_z : filter_linear, repeat_disable;
uniform int hover_slot = 0;
uniform vec4 door_uv = vec4(0.70, 0.28, 0.86, 0.62);

vec3 tinted(vec3 rgb, bool on) {
	if (!on) {
		return rgb;
	}
	return mix(rgb, vec3(1.0, 0.86, 0.55), 0.42);
}

void fragment() {
	vec4 shell = texture(shell_tex, UV);
	vec4 bed = texture(bed_tex, UV);
	vec4 shelf = texture(shelf_tex, UV);
	vec4 chair = texture(chair_tex, UV);
	vec4 desk = texture(desk_tex, UV);
	vec4 body = texture(char_tex, UV);
	vec4 cat = texture(cat_tex, UV);
	float bz = texture(bed_z, UV).r;
	float sz = texture(shelf_z, UV).r;
	float cz = texture(chair_z, UV).r;
	float dz = texture(desk_z, UV).r;
	float hz = texture(char_z, UV).r;
	float kz = texture(cat_z, UV).r;
	bool door_hot = hover_slot == 4 && UV.x > door_uv.x && UV.y > door_uv.y && UV.x < door_uv.z && UV.y < door_uv.w;
	shell.rgb = tinted(shell.rgb, door_hot);
	bed.rgb = tinted(bed.rgb, hover_slot == 1);
	shelf.rgb = tinted(shelf.rgb, hover_slot == 2);
	desk.rgb = tinted(desk.rgb, hover_slot == 3);
	cat.rgb = tinted(cat.rgb, hover_slot == 5);

	vec3 rgb = shell.rgb;
	float cover = shell.a;
	float front = 2.0;
	bool have = false;

	if (bed.a > 0.82 && bz < front) { rgb = bed.rgb; cover = 1.0; front = bz; have = true; }
	if (shelf.a > 0.82 && sz < front) { rgb = shelf.rgb; cover = 1.0; front = sz; have = true; }
	if (chair.a > 0.82 && cz < front) { rgb = chair.rgb; cover = 1.0; front = cz; have = true; }
	if (desk.a > 0.82 && dz < front) { rgb = desk.rgb; cover = 1.0; front = dz; have = true; }
	if (cat.a > 0.82 && kz < front) { rgb = cat.rgb; cover = 1.0; front = kz; have = true; }
	if (body.a > 0.82 && hz < front) { rgb = body.rgb; cover = 1.0; front = hz; have = true; }

	if (bed.a > 0.04 && bed.a <= 0.82 && (!have || bz <= front + 0.004)) {
		rgb = mix(rgb, bed.rgb, bed.a);
		cover = max(cover, bed.a);
	}
	if (shelf.a > 0.04 && shelf.a <= 0.82 && (!have || sz <= front + 0.004)) {
		rgb = mix(rgb, shelf.rgb, shelf.a);
		cover = max(cover, shelf.a);
	}
	if (chair.a > 0.04 && chair.a <= 0.82 && (!have || cz <= front + 0.004)) {
		rgb = mix(rgb, chair.rgb, chair.a);
		cover = max(cover, chair.a);
	}
	if (desk.a > 0.04 && desk.a <= 0.82 && (!have || dz <= front + 0.004)) {
		rgb = mix(rgb, desk.rgb, desk.a);
		cover = max(cover, desk.a);
	}
	if (cat.a > 0.04 && cat.a <= 0.82 && (!have || kz <= front + 0.004)) {
		rgb = mix(rgb, cat.rgb, cat.a);
		cover = max(cover, cat.a);
	}
	if (body.a > 0.04 && body.a <= 0.82 && (!have || hz <= front + 0.004)) {
		rgb = mix(rgb, body.rgb, body.a);
		cover = max(cover, body.a);
	}

	COLOR = vec4(rgb, cover);
}
