shader_type canvas_item;
// Title hero mech (ui/title_scene.gd): a diagonal band of light sweeps across the armour now and then
// (only where the art is opaque). `sweep` = the band's centre along the diagonal (0..1 crosses the art;
// outside that range it's off).

uniform float sweep = -1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float d = (UV.x * 0.8 + UV.y * 0.6) / 1.4;
	float band = 1.0 - smoothstep(0.0, 0.06, abs(d - sweep));
	float core = 1.0 - smoothstep(0.0, 0.015, abs(d - sweep));
	c.rgb += vec3(0.85, 0.93, 1.0) * (band * 0.28 + core * 0.25) * c.a;
	COLOR = c;
}
