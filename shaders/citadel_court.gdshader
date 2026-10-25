shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec2 court_center = vec2(0.0);
uniform vec3 stone_color : source_color = vec3(0.10, 0.13, 0.17);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz - court_center;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ring = radius / 3.0;
	float row = floor(ring);
	float sector = (angle / 6.2831853 + 0.5) * 24.0 + mod(row, 2.0) * 0.5;
	float radial_edge = min(fract(ring), 1.0 - fract(ring)) * 3.0;
	float angular_edge = min(fract(sector), 1.0 - fract(sector)) * max(1.0, radius) * 0.2618;
	float edge = min(radial_edge, angular_edge);
	float antialias = max(fwidth(edge) * 0.5, 0.002);
	float seam = smoothstep(0.012 - antialias, 0.048 + antialias, edge);
	float stone = fract(sin(floor(sector) * 127.1 + row * 311.7) * 43758.5);
	float age = sin(p.x * 0.6 + sin(p.y * 0.4)) * sin(p.y * 0.9) * 0.025;
	vec3 base = stone_color * (0.82 + stone * 0.22 + age);
	base *= mix(0.45, 1.0, seam);
	float inner_medallion = 1.0 - smoothstep(5.0, 5.2, radius);
	ALBEDO = mix(base, stone_color * 0.7, inner_medallion);
	ROUGHNESS = 0.67;
	METALLIC = 0.1;
}
