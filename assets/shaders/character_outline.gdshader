shader_type canvas_item;
// Thin dark outline for readability on busy backgrounds; `highlight` (0..1) turns it into a
// warm glow when the character is the current interaction target.

uniform vec4 outline_color : source_color = vec4(0.03, 0.04, 0.05, 0.75);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.82, 0.36, 1.0);
uniform float outline_px = 2.0;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float base_a = texture(TEXTURE, UV).a;
	vec2 o = TEXTURE_PIXEL_SIZE * mix(outline_px, outline_px * 2.0, highlight);
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(o.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(o.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, o.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, o.y)).a);
	a = max(a, texture(TEXTURE, UV + o * 0.7).a);
	a = max(a, texture(TEXTURE, UV - o * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(o.x, -o.y) * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(-o.x, o.y) * 0.7).a);
	vec3 line_rgb = mix(outline_color.rgb, highlight_color.rgb, highlight);
	float line_a = mix(outline_color.a, highlight_color.a, highlight) * a;
	// COLOR already holds texture * modulate.
	vec4 body = COLOR;
	COLOR = vec4(mix(line_rgb, body.rgb, base_a), max(body.a, line_a * (1.0 - base_a)));
}
