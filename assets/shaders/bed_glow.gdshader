shader_type canvas_item;
// Bed overlay: the same edge feathering as edge_fade.gdshader (so it still matches the room art),
// plus a soft gold outline glow around the bed silhouette while `highlight` > 0. Interactable drives
// `highlight` (0..1) when the bed is in the player's reach; nothing glows otherwise.

uniform vec2 fade = vec2(0.045, 0.03);
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.47, 1.0);
uniform float glow_px = 7.0;
uniform float glow_strength = 0.7;

void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV);
	float edge = smoothstep(0.0, fade.x, d.x) * smoothstep(0.0, fade.y, d.y);
	// COLOR already holds texture * modulate.
	vec4 body = COLOR;
	if (highlight > 0.001) {
		float near = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5235988;
			vec2 dir = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE;
			near = max(near, texture(TEXTURE, UV + dir * glow_px * 0.5).a);
			near = max(near, texture(TEXTURE, UV + dir * glow_px).a * 0.55);
		}
		float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
		float g = near * (1.0 - body.a) * highlight * glow_strength * pulse;
		float out_a = body.a + g * (1.0 - body.a);
		vec3 rgb = body.rgb * (1.0 + 0.06 * highlight);
		body = vec4((rgb * body.a + glow_color.rgb * g * (1.0 - body.a)) / max(out_a, 0.0001), out_a);
	}
	body.a *= edge;
	COLOR = body;
}
