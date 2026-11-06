shader_type canvas_item;
// HD map sharpening (contrast-adaptive, in the spirit of AMD CAS) for the painted arena maps
// (environment/scenic_arena.gd). The 3312 px paintings are stretched 1.5x in the world and more again on
// HD / 4K screens; this pulls their detail (paving cracks, panel lines, snow) back into focus. Sharpening
// is weaker where the local contrast is already high, so edges don't ring or halo. 5 texture taps.
// Neighbours are one SCREEN pixel away (UV derivatives), not one texel: the painting is magnified, and
// texel-spaced taps would print the texel grid onto it.

uniform float amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 px = max(abs(dFdx(UV)) + abs(dFdy(UV)), TEXTURE_PIXEL_SIZE * 0.25);
	vec4 base = texture(TEXTURE, UV);
	vec3 c = base.rgb;
	vec3 n = texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb;
	vec3 s = texture(TEXTURE, UV + vec2(0.0, px.y)).rgb;
	vec3 e = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb;
	vec3 w = texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb;
	vec3 mn = min(c, min(min(n, s), min(e, w)));
	vec3 mx = max(c, max(max(n, s), max(e, w)));
	vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(0.0001)), 0.0, 1.0));
	vec3 wgt = amp * (-1.0 / mix(8.0, 5.0, amount));
	vec3 sharp = (c + (n + s + e + w) * wgt) / (1.0 + 4.0 * wgt);
	// COLOR arrives as texture x modulate: keep any modulate tint (e.g. weather) on the sharpened colour.
	vec3 tint = clamp(COLOR.rgb / max(c, vec3(0.001)), 0.0, 2.0);
	COLOR = vec4(clamp(sharp, 0.0, 1.0) * tint, COLOR.a);
}
