shader_type canvas_item;
render_mode blend_add, unshaded;
// Gundam-style mega beam (the Beam Cannon, player/weapons/beam_cannon.gd), drawn on a quad whose UV.x
// runs muzzle -> end and UV.y across (0.5 = the centre line). The quad is 1.6x the beam's radius each side.
//   core     a blown-out white core, ~40% of the beam's width
//   corona   a saturated band of the beam colour around it, and a soft bloom past its edge
//   rings    bright ring ripples racing down the beam toward the target
//   helix    a twin strand of light spiralling round it (the far strand dimmer)
//   scans    thin streaks flickering along it just inside its edge
//   pulse    the width throbs fast; `thin` squeezes it to a line as the shot ends
//   head     while the beam is shooting out (`reach` < 1) its head is a bright flare
// All maths (no textures), GL Compatibility safe.

uniform vec4 beam_color : source_color = vec4(1.0, 0.35, 0.8, 1.0);
uniform float length_px = 1000.0;
uniform float t = 0.0;
uniform float intensity = 1.0;
uniform float reach = 1.0;
uniform float thin = 1.0;

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float x = UV.x * length_px;
	float head = reach * length_px;
	float pulse = 1.0 + 0.07 * sin(t * 95.0) + 0.05 * sin(x * 0.021 - t * 48.0);
	float w = max(thin * pulse, 0.03);
	float ys = (UV.y - 0.5) * 2.0 * 1.6 / w;  // signed: 0 = centre line, +-1 = the beam's edge
	float r = abs(ys);
	vec3 col = beam_color.rgb;
	vec3 white = vec3(1.0);
	float core = 1.0 - smoothstep(0.3, 0.44, r);
	float corona = exp(-pow(max(r - 0.28, 0.0) / 0.42, 1.7));
	float bloom = exp(-r * 1.6) * 0.45;
	float ring = pow(0.5 + 0.5 * sin(x * 0.045 - t * 55.0), 10.0) * (1.0 - smoothstep(0.35, 1.2, r));
	float ph = x * 0.032 - t * 30.0;
	float h1 = (1.0 - smoothstep(0.0, 0.11, abs(ys - 0.9 * sin(ph)))) * (0.55 + 0.45 * cos(ph));
	float h2 = (1.0 - smoothstep(0.0, 0.11, abs(ys + 0.9 * sin(ph)))) * (0.55 - 0.45 * cos(ph)) * 0.6;
	float dash = step(0.45, hash1(floor(x * 0.012 - t * 22.0) + sign(ys) * 7.0));
	float scan = (1.0 - smoothstep(0.0, 0.045, abs(r - 0.66))) * dash;
	vec3 c = white * core
		+ mix(col, white, 0.22) * corona * 0.95
		+ col * bloom
		+ mix(col, white, 0.65) * ring * 0.75
		+ mix(col, white, 0.55) * (h1 + h2) * 0.85
		+ mix(col, white, 0.7) * scan * 0.5;
	// The head flares while the beam shoots out; past the head there is no beam yet.
	float hx = x - head;
	float flare = exp(-hx * hx / 500.0) * exp(-r * r * 0.5) * 2.2 * (1.0 - step(0.999, reach));
	c += mix(col, white, 0.6) * flare;
	float ends = smoothstep(0.0, 14.0, x) * (1.0 - smoothstep(head - 4.0, head + 18.0, x) * (1.0 - step(0.999, reach)));
	COLOR = vec4(c * intensity * ends, 1.0);
}
