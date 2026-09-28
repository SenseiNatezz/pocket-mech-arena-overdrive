shader_type canvas_item;
// Title logo glint: a soft diagonal band of light sweeps across the logo's opaque pixels.
// `sweep` goes from about -0.4 (off the left) to 1.6 (off the right); set by ui/main_menu.gd.

uniform float sweep = -1.0;
uniform vec4 shine_color : source_color = vec4(0.85, 0.97, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = abs(UV.x + (UV.y - 0.5) * 0.45 - sweep);
	float band = smoothstep(0.09, 0.0, d);
	COLOR = c;
	COLOR.rgb += shine_color.rgb * band * 0.55 * c.a * step(0.6, c.a);
}
