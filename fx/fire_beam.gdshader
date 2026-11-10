shader_type canvas_item;
render_mode blend_add, unshaded;
// VULCAN's core beams (enemies/bosses/vulcan_boss.gd): a furnace blast, not a flat stripe. Drawn on a quad
// whose UV.x runs core -> end and UV.y across it (0.5 = centre line); the quad is 1.8x the beam's radius each
// side so the flames have room. Layers, all maths (no textures), GL Compatibility safe:
//   core     a blown-out white-hot centre that flickers
//   hot      a yellow band round it
//   fire     the orange body, its edges torn by fbm noise that flows away from the boss (flames licking out)
//   haze     a deep-red outer heat haze, also turbulent
//   streaks  thin bright speed lines racing outward inside the body
//   pressure bright pressure rings racing down the beam; surges = fat bulges of fire racing outward
//   sparks   specks thrown off past its edge
//   cone     narrow where it leaves the core, flaring to full width
//   head     while the blast is shooting out (`reach` < 1) its front is a bright fireball
//   burst    `flare` (0..1) blows the whole beam out wider and whiter for the release flash
//   thin     squeezes it to a seam as the blast dies

uniform float length_px = 700.0;
uniform float t = 0.0;
uniform float intensity = 1.0;
uniform float reach = 1.0;
uniform float thin = 1.0;
uniform float flare = 0.0;
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
	for (int i = 0; i < 4; i++) {
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
	float pulse = 1.0 + 0.06 * sin(t * 80.0 + seed) + 0.05 * sin(x * 0.02 - t * 36.0);
	// Surges: fat bulges of fire racing outward down the beam.
	float surge = pow(0.5 + 0.5 * sin(x * 0.011 - t * 26.0 + seed), 5.0);
	pulse += 0.28 * surge;
	float w = max(thin * pulse * cone * (1.0 + 0.3 * flare), 0.04);
	float ys = (UV.y - 0.5) * 2.0 * SPREAD / w;   // 0 = centre line, +-1 = the beam's edge
	float r = abs(ys);
	// Turbulence flowing away from the core; it eats into the edges more than the centre.
	vec2 q = vec2(x * 0.016 - t * 13.0, ys * 1.3 + seed);
	float n = fbm(q);
	float n2 = fbm(vec2(x * 0.034 - t * 24.0, ys * 2.4 - t * 1.5 + seed * 3.0));
	float rr = r - (n - 0.5) * 1.7 * smoothstep(0.15, 1.0, r) - (n2 - 0.5) * 0.45;
	vec3 white = vec3(1.0, 0.98, 0.92);
	vec3 yellow = vec3(1.0, 0.82, 0.38);
	vec3 orange = vec3(1.0, 0.42, 0.08);
	vec3 red = vec3(0.62, 0.1, 0.02);
	float core = (1.0 - smoothstep(0.16, 0.34, rr)) * (0.85 + 0.15 * sin(t * 90.0 + x * 0.05));
	float hot = exp(-pow(max(rr, 0.0) / 0.5, 2.4)) * (0.65 + 0.5 * n2);
	float fire = (1.0 - smoothstep(0.45, 1.0, rr)) * (0.3 + 1.2 * n * n + 0.5 * surge);
	float haze = (1.0 - smoothstep(0.7, 1.75, rr)) * (0.25 + 0.6 * n2) * 0.55;
	// Speed lines: short bright dashes at a few fixed heights, racing outward.
	float lane = floor(ys * 3.0);
	float dash = step(0.62, hash(vec2(floor(x * 0.018 - t * 26.0 - hash(vec2(lane, seed)) * 30.0), lane)));
	float streak = dash * (1.0 - smoothstep(0.0, 0.07, abs(fract(ys * 3.0) - 0.5))) * (1.0 - smoothstep(0.55, 0.95, r));
	float pressure = pow(0.5 + 0.5 * sin(x * 0.028 - t * 42.0), 14.0) * (1.0 - smoothstep(0.3, 1.0, rr));
	// Sparks thrown off the flames: specks on a grid that flows outward, beyond the beam's edge.
	vec2 sg = vec2(x * 0.07 - t * 40.0, ys * 2.2 * w + t * 3.0 * sign(ys));
	vec2 sc = floor(sg);
	vec2 sf = fract(sg) - 0.5;
	float sh = hash(sc + seed);
	float spark = step(0.9, sh) * (1.0 - smoothstep(0.08, 0.2, length(sf))) * smoothstep(0.7, 1.0, r) * (1.0 - smoothstep(1.4, 1.75, r));
	vec3 c = white * core * 1.25
		+ yellow * hot
		+ orange * fire
		+ red * haze
		+ mix(yellow, white, 0.5) * streak * 0.6
		+ mix(orange, white, 0.55) * pressure * 0.7
		+ yellow * spark * 1.4;
	c *= 1.0 + flare * 0.8;
	// The front of the blast while it is shooting out: a boiling fireball.
	float hx = x - head;
	float shooting = 1.0 - step(0.999, reach);
	float ball = exp(-hx * hx / 900.0) * exp(-r * r * 0.35) * (1.6 + 0.8 * n) * shooting;
	c += mix(yellow, white, 0.5) * ball;
	// Ends: grows out of the core, frays out past the head (or at the end of its reach).
	float tail = 1.0 - smoothstep(head - 40.0 - 60.0 * n, head + 10.0, x);
	float ends = smoothstep(0.0, 24.0, x) * tail;
	COLOR = vec4(c * intensity * ends, 1.0);
}
