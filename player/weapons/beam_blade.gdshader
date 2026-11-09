shader_type canvas_item;
render_mode blend_add, unshaded;

// Gundam-style beam saber blade (player/weapons/melee_rig.gd BeamLayer), drawn additively on a quad
// around the blade. UV is in world pixels: x from the emitter (0) toward the tip, y across the blade
// (already divided by the weapon's width scale). COLOR.rgb = the beam colour, COLOR.a = blade length / 512.
//   core   a blown-out white core, thick at the emitter, tapering to a needle point over the last ~22%
//   inner  a tight saturated glow hugging the core (washes toward white near it)
//   halo   a wide soft bloom in the beam colour, rounder at the tip
//   flare  a bright bloom where the beam leaves the emitter
// A fast, faint width/brightness hum keeps it alive without strobing.

uniform float core_hw = 2.6;
uniform float inner_hw = 6.0;
uniform float halo_px = 8.0;

void fragment() {
	float len = max(COLOR.a * 512.0, 1.0);
	vec2 p = UV;
	float t = p.x / len;
	float hum = 1.0 + 0.07 * sin(TIME * 131.0 + p.x * 0.09) * sin(TIME * 23.0);
	// Core: needle-pointed, cut off just past the tip and just behind the emitter.
	float taper = 1.0 - 0.9 * smoothstep(0.72, 1.0, t);
	float w = core_hw * taper * hum;
	float ax = p.x < 0.0 ? -p.x * 1.6 : max(p.x - len, 0.0) * 6.0;
	float dc = length(vec2(ax, p.y));
	float core = 1.0 - smoothstep(w * 0.55, w * 1.15 + 0.35, dc);
	// Glow: a rounder, wider envelope that narrows a little toward the tip.
	float gt = 1.0 - 0.45 * smoothstep(0.65, 1.05, t);
	float ag = p.x < 0.0 ? -p.x : max(p.x - len, 0.0);
	float dg = length(vec2(ag, p.y)) / gt;
	float inner = exp(-(dg * dg) / (inner_hw * inner_hw));
	float halo = exp(-dg / halo_px) * (0.88 + 0.12 * sin(TIME * 37.0 + 1.3));
	float flare = exp(-dot(p, p) / 26.0);
	vec3 col = COLOR.rgb;
	vec3 c = vec3(1.0) * (core + flare * 0.85)
		+ mix(col, vec3(1.0), 0.3) * inner * 0.95
		+ col * halo * 0.72;
	COLOR = vec4(c, 1.0);
}
