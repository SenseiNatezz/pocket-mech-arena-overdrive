shader_type canvas_item;
// A map's colour mood (environment/map_life.gd): the screen edges fall off to a dark tint (`edge`, its alpha =
// how dark the corners get) and a faint colour wash (`wash`, its alpha = how strong) lies over the picture.
uniform vec4 edge : source_color = vec4(0.0, 0.0, 0.1, 0.4);
uniform vec4 wash : source_color = vec4(1.0, 1.0, 1.0, 0.04);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.92);
	float v = smoothstep(0.34, 0.78, length(d)) * edge.a;
	float a = v + wash.a * (1.0 - v);
	COLOR = vec4(mix(wash.rgb, edge.rgb, v / max(a, 0.0001)), a);
}
