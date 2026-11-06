shader_type canvas_item;
render_mode blend_add, unshaded;
// Animated energy beam (Beam Cannon, Sniper Beam): drawn on a quad whose UV.x runs muzzle -> end and
// UV.y across the beam (0.5 = centre). Layers: a flickering white-hot core, a plasma body whose
// brightness flows toward the target (scrolling value-noise fbm), electric filaments snaking along it,
// pulse rings racing down it, and a soft outer glow. All maths (no textures), GL Compatibility safe.

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 beam_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.35, 1.0, 1.0);
// Beam length in px (so patterns keep their size however long the beam is).
uniform float length_px = 1000.0;
// 0..1 overall strength (fades in / out), and the beam's own clock (seconds).
uniform float intensity = 1.0;
uniform float t = 0.0;
// How fast the plasma flows toward the target.
uniform float flow_speed = 9.0;

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
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float x = UV.x * length_px;
	float y = (UV.y - 0.5) * 2.0;
	float ay = abs(y);
	float flow = fbm(vec2(x * 0.012 - t * flow_speed, y * 2.0 + t * 1.3));
	float flow2 = fbm(vec2(x * 0.03 - t * flow_speed * 1.8, y * 4.0 - t * 2.0));
	// The beam's width breathes along its length.
	float wob = 0.82 + 0.12 * sin(x * 0.035 - t * 30.0) + 0.16 * (flow - 0.5);
	float d = ay / wob;
	float core = smoothstep(0.2, 0.0, d) * (0.85 + 0.15 * sin(t * 70.0));
	float body = smoothstep(0.72, 0.12, d) * (0.55 + 0.7 * flow);
	float glow = smoothstep(1.0, 0.25, d) * 0.32 * (0.7 + 0.6 * flow2);
	// Electric filaments wandering across the body.
	float f1 = sin(x * 0.045 - t * 40.0 + flow * 6.0) * 0.42;
	float f2 = sin(x * 0.027 + t * 33.0 + flow2 * 5.0) * 0.55;
	float fil = smoothstep(0.07, 0.0, abs(y - f1)) + 0.8 * smoothstep(0.05, 0.0, abs(y - f2));
	fil *= smoothstep(1.0, 0.35, ay) * (0.4 + flow2);
	// Pulse rings racing toward the target.
	float rings = smoothstep(0.8, 1.0, sin(x * 0.02 - t * 26.0)) * smoothstep(0.95, 0.2, d) * 0.55;
	// Soft ends (the muzzle flash and impact cover them).
	float ends = smoothstep(0.0, 0.025, UV.x) * smoothstep(1.0, 0.975, UV.x);
	vec3 col = core_color.rgb * core * 1.7 + beam_color.rgb * (body + rings) + edge_color.rgb * glow
		+ mix(beam_color.rgb, core_color.rgb, 0.5) * fil * 1.3;
	float a = clamp(core + body + glow + fil + rings, 0.0, 1.0);
	COLOR = vec4(col * intensity * ends, a * intensity * ends);
}
