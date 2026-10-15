shader_type canvas_item;
// Soft, darkened copy of a location background used to fill the screen around the room.
// Needs a mipmapped texture (all res://assets PNGs import with mipmaps).

uniform float blur_lod : hint_range(0.0, 8.0) = 4.0;
uniform vec4 tint : source_color = vec4(0.42, 0.45, 0.5, 1.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * exp2(blur_lod);
	vec4 c = textureLod(TEXTURE, UV, blur_lod) * 0.4;
	c += textureLod(TEXTURE, UV + vec2(px.x, px.y), blur_lod) * 0.15;
	c += textureLod(TEXTURE, UV + vec2(-px.x, px.y), blur_lod) * 0.15;
	c += textureLod(TEXTURE, UV + vec2(px.x, -px.y), blur_lod) * 0.15;
	c += textureLod(TEXTURE, UV + vec2(-px.x, -px.y), blur_lod) * 0.15;
	COLOR = vec4(c.rgb * tint.rgb, c.a * tint.a);
}
