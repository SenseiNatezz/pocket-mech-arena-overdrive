shader_type canvas_item;
// Customize-screen Gundam: repaints the saturated BLUE armor panels and the MAGENTA energy glow
// (eyes + beam saber) of the showcase render independently, keeping all shading.
// Targets are plain colors; low-saturation targets (black / white) are handled via value.

uniform vec4 armor_color : source_color = vec4(0.16, 0.36, 0.95, 1.0);
uniform bool armor_original = true;
uniform vec4 energy_color : source_color = vec4(1.0, 0.35, 0.8, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

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

// Recolor a pixel (hsv) toward `target`, keeping its relative brightness.
vec3 paint(vec3 hsv, vec3 target, float ref_val) {
	vec3 t = rgb2hsv(target);
	float v = hsv.z / max(ref_val, 0.01);
	if (t.y < 0.2) {
		// Black / white / grey: brightness follows the target value.
		return vec3(clamp(v * mix(0.35, 1.05, t.z) * (t.z < 0.3 ? 0.55 : 1.0), 0.0, 1.0));
	}
	return hsv2rgb(vec3(t.x, clamp(hsv.y * t.y * 1.05, 0.0, 1.0), clamp(v * t.z, 0.0, 1.0)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 hsv = rgb2hsv(c.rgb);
	float sat = smoothstep(0.28, 0.45, hsv.y);
	float armor = smoothstep(0.55, 0.59, hsv.x) * (1.0 - smoothstep(0.71, 0.75, hsv.x)) * sat;
	float energy = smoothstep(0.76, 0.8, hsv.x) * (1.0 - smoothstep(0.96, 0.99, hsv.x)) * sat;
	vec3 rgb = c.rgb;
	if (!armor_original) {
		rgb = mix(rgb, paint(hsv, armor_color.rgb, 0.85), armor);
	}
	rgb = mix(rgb, paint(hsv, energy_color.rgb, 0.95), energy);
	COLOR = vec4(mix(rgb, vec3(1.0), flash), c.a);
}
