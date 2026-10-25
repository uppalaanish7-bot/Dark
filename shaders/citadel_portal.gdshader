shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.24, 0.85, 1.0, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float edge = 1.0 - smoothstep(0.78, 1.0, radius);
	float vortex = sin(angle * 5.0 - radius * 21.0 + TIME * 2.2);
	float threads = pow(max(0.0, vortex), 8.0) * smoothstep(0.05, 0.7, radius);
	float corona = exp(-pow((radius - 0.82) * 20.0, 2.0));
	float heart = pow(max(0.0, 1.0 - radius), 3.0);
	vec3 cold = core_color.rgb * (0.15 + threads * 0.85 + corona * 1.2);
	vec3 warm = vec3(1.0, 0.62, 0.23) * heart * 1.5;
	ALBEDO = cold + warm;
	ALPHA = edge * (0.25 + threads * 0.6 + corona * 0.5 + heart * 0.6);
}
