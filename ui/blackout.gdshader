shader_type canvas_item;
// BLACKOUT Endless twist (ui/hud.gd): darkness over the arena except a pool of light around the mech.
// `center` and `rect_size` are in the HUD's logical pixels; `strength` fades the effect in and out.

uniform vec2 center = vec2(640.0, 360.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float radius = 300.0;
uniform float strength = 0.0;
uniform float t = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	// The light pool breathes and flickers slightly, like a failing floodlight.
	float r = radius * (1.0 + 0.03 * sin(t * 2.0) + 0.015 * sin(t * 23.0));
	float d = distance(p, center);
	float dark = smoothstep(r * 0.5, r, d);
	COLOR = vec4(0.0, 0.01, 0.03, dark * strength * 0.92);
}
