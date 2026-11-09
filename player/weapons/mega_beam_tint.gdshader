shader_type canvas_item;
// Normal-blend colour band under the additive mega beam (player/weapons/mega_beam.gdshader, same quad and
// parameters), so the beam's corona stays saturated even over bright floors (snow, sand) where additive
// light alone washes out to white.

uniform vec4 beam_color : source_color = vec4(1.0, 0.35, 0.8, 1.0);
uniform float length_px = 1000.0;
uniform float t = 0.0;
uniform float intensity = 1.0;
uniform float reach = 1.0;
uniform float thin = 1.0;

void fragment() {
	float x = UV.x * length_px;
	float head = reach * length_px;
	float pulse = 1.0 + 0.07 * sin(t * 95.0) + 0.05 * sin(x * 0.021 - t * 48.0);
	float w = max(thin * pulse, 0.03);
	float r = abs((UV.y - 0.5) * 2.0 * 1.6 / w);
	float band = smoothstep(0.18, 0.45, r) * (1.0 - smoothstep(0.85, 1.4, r));
	float ends = smoothstep(0.0, 14.0, x) * (1.0 - smoothstep(head - 4.0, head + 18.0, x) * (1.0 - step(0.999, reach)));
	COLOR = vec4(beam_color.rgb * 0.8, band * 0.55 * intensity * ends);
}
