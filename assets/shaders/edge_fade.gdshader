shader_type canvas_item;
// Feathers the outer edge of a full-room image so it blends into the blurred backdrop.
// Apply the same material to overlays cut from that image (e.g. the bed layer) so edges match.

uniform vec2 fade = vec2(0.045, 0.03);

void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV);
	float a = smoothstep(0.0, fade.x, d.x) * smoothstep(0.0, fade.y, d.y);
	COLOR.a *= a;
}
