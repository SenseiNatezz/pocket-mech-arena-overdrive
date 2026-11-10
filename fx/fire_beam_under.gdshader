shader_type canvas_item;
render_mode blend_mix, unshaded;
// The dark side of VULCAN's core beams (fx/fire_beam.gdshader is drawn over it, additive): a band of
// soot-dark smoke and scorched air along the beam, its edges torn by the same kind of flowing noise. On the
// orange forge floor an additive beam alone washes out into a flat bar; this gives it a dark rim to burn
// against, so its white-hot core and flames read. Same quad / UVs / uniforms as the beam itself.

uniform float length_px = 700.0;
uniform float t = 0.0;
uniform float intensity = 1.0;
uniform float reach = 1.0;
uniform float thin = 1.0;
uniform float seed = 0.0;

const float SPREAD = 1.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float x = UV.x * length_px;
	float head = reach * length_px;
	float cone = mix(0.55, 1.0, smoothstep(0.0, 170.0, x));
	float w = max(thin * cone, 0.04);
	float ys = (UV.y - 0.5) * 2.0 * SPREAD / w;
	float r = abs(ys);
	float n = fbm(vec2(x * 0.012 - t * 8.0, ys * 1.1 + seed * 2.0));
	float rr = r - (n - 0.5) * 1.3;
	float a = (1.0 - smoothstep(0.9, 1.65, rr)) * 0.62;
	vec3 col = mix(vec3(0.07, 0.03, 0.02), vec3(0.32, 0.07, 0.02), 1.0 - smoothstep(0.4, 1.4, rr));
	float ends = smoothstep(0.0, 30.0, x) * (1.0 - smoothstep(head - 50.0, head + 10.0, x));
	COLOR = vec4(col, a * intensity * ends);
}
