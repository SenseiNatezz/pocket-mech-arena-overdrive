shader_type canvas_item;

// 0 = normal, 1 = fully tinted with flash_color (used for hit feedback).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Armor paint (player mech only): remaps blue armor hues to target_hue.
uniform bool recolor = false;
uniform float target_hue = 0.0;
uniform float sat_mult = 1.0;
uniform float val_mult = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (recolor) {
		vec3 hsv = rgb2hsv(c.rgb);
		// Only saturated blues (the armor panels), not whites, greys, gold trim or cyan glows.
		float blue = smoothstep(0.54, 0.58, hsv.x) * (1.0 - smoothstep(0.74, 0.78, hsv.x)) * smoothstep(0.22, 0.4, hsv.y);
		vec3 painted = hsv2rgb(vec3(target_hue, clamp(hsv.y * sat_mult, 0.0, 1.0), clamp(hsv.z * val_mult, 0.0, 1.0)));
		c.rgb = mix(c.rgb, painted, blue);
	}
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
