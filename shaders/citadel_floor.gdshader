shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 tile = floor((p + vec2(mod(floor(p.y / 6.0), 2.0) * 3.0, 0.0)) / 6.0);
	vec2 uv = fract((p + vec2(mod(floor(p.y / 6.0), 2.0) * 3.0, 0.0)) / 6.0);
	float border = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float antialias = max(fwidth(border) * 0.55, 0.001);
	float seam = smoothstep(0.005 - antialias, 0.018 + antialias, border);
	float distance_fade = smoothstep(65.0, 155.0, length(world_position - CAMERA_POSITION_WORLD));
	seam = mix(seam, 1.0, distance_fade * 0.85);
	float veins = sin(p.x * 0.48 + sin(p.y * 0.26) * 2.2) * sin(p.y * 0.62 + p.x * 0.14);
	float stone = hash(tile) * 0.2 + 0.86 + veins * 0.028;
	vec3 base = vec3(0.16, 0.19, 0.22) * stone;
	float aisle = 1.0 - smoothstep(12.8, 13.1, abs(p.x));
	base = mix(base, vec3(0.095, 0.112, 0.137) * stone, aisle * 0.72);
	base *= mix(0.32, 1.0, seam);
	float brass = 1.0 - smoothstep(0.04, 0.09, abs(abs(p.x) - 12.5));
	float secondary = 1.0 - smoothstep(0.025, 0.065, abs(abs(p.x) - 11.9));
	base = mix(base, vec3(0.38, 0.255, 0.108), max(brass, secondary * 0.7));
	ALBEDO = base;
	ROUGHNESS = mix(0.72, 0.42, max(brass, aisle * 0.4));
	METALLIC = max(brass * 0.55, secondary * 0.35);
}
