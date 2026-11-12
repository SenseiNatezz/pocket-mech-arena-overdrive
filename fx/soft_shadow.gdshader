shader_type canvas_item;
// Soft drop shadow (player/mech_shadow.gd): draws the texture's shape in black, blurred over a few px.
// `strength` = how dark, `blur` = how far the edge spreads (texture px).
uniform float strength = 0.35;
uniform float blur = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	float a = texture(TEXTURE, UV).a * 0.2;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a * 0.1;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a * 0.1;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a * 0.1;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a * 0.1;
	a += texture(TEXTURE, UV + px).a * 0.1;
	a += texture(TEXTURE, UV - px).a * 0.1;
	a += texture(TEXTURE, UV + vec2(px.x, -px.y)).a * 0.1;
	a += texture(TEXTURE, UV + vec2(-px.x, px.y)).a * 0.1;
	COLOR = vec4(0.0, 0.0, 0.0, a * strength);
}
