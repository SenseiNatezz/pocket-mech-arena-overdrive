shader_type canvas_item;
// Molten slag puddle (enemies/lava_pool.gd), procedural: churning magma (two layers of flowing noise,
// orange -> yellow -> white-hot), dark crust plates that spread in from the edge and over the whole pool
// as it cools (their cracks keep glowing), a lumpy outline with a scorched rim, and a soft heat glow on
// the floor around it. Drawn on a square whose half-size is 1.35 x the pool radius (UV 0..1).

uniform float hot : hint_range(0.0, 1.0) = 1.0;   // 1 molten .. 0 crusted over
uniform float grow : hint_range(0.0, 1.0) = 1.0;  // swell-in / shrink
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.17) * 43758.5453);
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
	vec2 p = (UV * 2.0 - 1.0) * 1.35;   // pool radius = 1
	float r = length(p);
	float ang = atan(p.y, p.x);
	// Lumpy outline.
	float rim = (0.86 + 0.2 * fbm(vec2(cos(ang), sin(ang)) * 1.6 + seed)) * grow;
	float inside = 1.0 - smoothstep(rim - 0.05, rim, r);
	float k = r / max(rim, 0.001);
	// Churning magma.
	float t = TIME;
	vec2 q = p * 2.6;
	float flow = fbm(q + vec2(fbm(q * 1.3 + vec2(t * 0.25, -t * 0.18)), fbm(q * 1.1 - vec2(t * 0.2, t * 0.12))) * 1.6);
	vec3 magma = mix(vec3(0.75, 0.12, 0.02), vec3(1.0, 0.55, 0.08), smoothstep(0.25, 0.55, flow));
	magma = mix(magma, vec3(1.0, 0.88, 0.4), smoothstep(0.55, 0.78, flow));
	magma = mix(magma, vec3(1.0, 0.98, 0.82), smoothstep(0.78, 0.92, flow) * 0.8);
	// Crust: plates where a slow noise is above a threshold that drops as it cools and near the edge.
	float plates = fbm(p * 3.2 + vec2(seed * 2.0, t * 0.03));
	float cool = clamp((1.0 - hot) * 1.1 + smoothstep(0.55, 1.0, k) * 0.55, 0.0, 1.0);
	float th = mix(0.78, 0.18, cool);
	float crust = smoothstep(th - 0.025, th + 0.025, plates);
	float crack_glow = 1.0 - smoothstep(0.0, 0.05, abs(plates - th));
	vec3 crust_col = mix(vec3(0.09, 0.05, 0.04), vec3(0.2, 0.12, 0.09), noise(p * 14.0));
	vec3 col = mix(magma, crust_col, crust);
	col += vec3(1.0, 0.45, 0.08) * crack_glow * (0.4 + 0.6 * hot) * 0.9;
	// Scorched dark rim.
	col = mix(col, vec3(0.08, 0.04, 0.03), smoothstep(0.86, 1.0, k) * 0.85);
	// Molten pools dim to dull red as the whole thing cools.
	col *= mix(0.55, 1.0, hot);
	// Heat glow on the floor around it (outside the pool).
	float halo = (1.0 - smoothstep(rim, rim + 0.32, r)) * (1.0 - inside) * 0.38 * hot;
	vec3 halo_col = vec3(1.0, 0.4, 0.08);
	COLOR.rgb = mix(halo_col, col, inside);
	COLOR.a = max(inside, halo) * COLOR.a;
}
