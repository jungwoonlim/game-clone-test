// Tilt-shift: sharp through a horizontal band, blurred above and below.
//
// The blur is what makes a 3D scene read as a miniature, and it is the one
// piece of the HD-2D look the Compatibility renderer has no built-in depth of
// field for. Nine taps is enough at this resolution.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float focus_center : hint_range(0.0, 1.0) = 0.56;
uniform float focus_width : hint_range(0.0, 0.6) = 0.20;
uniform float blur_pixels : hint_range(0.0, 6.0) = 2.4;
uniform float vignette : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec2 uv = SCREEN_UV;
	float distance_from_band = abs(uv.y - focus_center);
	float amount = clamp((distance_from_band - focus_width) / max(focus_width, 0.001),
			0.0, 1.0);
	float radius = amount * blur_pixels;

	vec4 total = vec4(0.0);
	float weight_sum = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * radius * SCREEN_PIXEL_SIZE;
			float weight = (x == 0 && y == 0) ? 2.0 : 1.0;
			total += texture(screen_tex, uv + offset) * weight;
			weight_sum += weight;
		}
	}

	vec4 color = total / weight_sum;
	// A soft corner falloff finishes the diorama feel.
	float edge = distance(uv, vec2(0.5)) * 1.35;
	color.rgb *= 1.0 - vignette * smoothstep(0.5, 1.1, edge);
	COLOR = color;
}
