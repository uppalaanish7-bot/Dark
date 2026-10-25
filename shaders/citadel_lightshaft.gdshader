shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 shaft_color : source_color = vec4(0.28, 0.43, 0.68, 0.05);

void fragment() {
	float horizontal = pow(max(0.0, sin(UV.x * 3.14159265)), 2.0);
	float vertical = smoothstep(0.0, 0.23, UV.y) * (1.0 - smoothstep(0.6, 1.0, UV.y));
	float shimmer = 0.86 + sin(UV.y * 11.0 + TIME * 0.23) * 0.14;
	ALBEDO = shaft_color.rgb;
	ALPHA = shaft_color.a * horizontal * vertical * shimmer;
}
