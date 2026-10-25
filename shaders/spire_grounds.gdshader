shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;

float random_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_value(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random_value(i), random_value(i + vec2(1.0, 0.0)), f.x),
		mix(random_value(i + vec2(0.0, 1.0)), random_value(i + vec2(1.0)), f.x), f.y);
}

float lantern_pool(vec2 p, float z) {
	vec2 delta = vec2(abs(p.x) - 13.0, p.y - z);
	return exp(-dot(delta, delta) * 0.030);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float large_noise = noise_value(p * 0.075);
	float small_noise = noise_value(p * 1.6);
	vec3 earth = mix(vec3(0.060, 0.078, 0.071), vec3(0.118, 0.135, 0.104), large_noise);
	earth *= 0.88 + small_noise * 0.17;
	float center_path = (1.0 - smoothstep(8.9, 9.3, abs(p.x))) * step(-10.0, p.y) * step(p.y, 217.0);
	float entry_plaza = (1.0 - smoothstep(77.8, 78.2, abs(p.x))) * (1.0 - smoothstep(35.8, 36.2, abs(p.y - 22.0)));
	float arrival = 1.0 - smoothstep(25.8, 26.2, length(p - vec2(0.0, 168.0)));
	float round_court = 1.0 - smoothstep(27.8, 28.2, length(p - vec2(0.0, 84.0)));
	float cross_path = (1.0 - smoothstep(4.8, 5.2, abs(p.y - 84.0))) * (1.0 - smoothstep(163.8, 164.2, abs(p.x)));
	float side_path = (1.0 - smoothstep(4.8, 5.2, abs(abs(p.x) - 111.0))) * step(-125.0, p.y) * step(p.y, 199.0);
	float rear_path = (1.0 - smoothstep(4.8, 5.2, abs(p.y + 117.0))) * (1.0 - smoothstep(112.0, 116.0, abs(p.x)));
	float path = max(max(max(center_path, entry_plaza), max(arrival, round_court)), max(cross_path, max(side_path, rear_path)));
	vec2 stone_pos = p + vec2(mod(floor(p.y / 3.0), 2.0) * 2.0, 0.0);
	vec2 tile = floor(stone_pos / vec2(4.0, 3.0));
	vec2 uv = fract(stone_pos / vec2(4.0, 3.0));
	float border = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float aa = max(fwidth(border), 0.001);
	float joint = smoothstep(0.002 - aa, 0.009 + aa, border);
	joint = mix(joint, 1.0, smoothstep(65.0, 170.0, length(world_position - CAMERA_POSITION_WORLD)) * 0.8);
	vec3 stone = vec3(0.195, 0.214, 0.217) * (0.91 + random_value(tile) * 0.13);
	stone *= mix(0.56, 1.0, joint);
	stone *= 0.97 + small_noise * 0.035;
	ALBEDO = mix(earth, stone, path);
	// Static soft pools keep the long route legible without dozens of dynamic
	// lights competing for the compatibility renderer's per-mesh light limit.
	float pools = lantern_pool(p, 8.0) + lantern_pool(p, 43.0) + lantern_pool(p, 119.0)
		+ lantern_pool(p, 151.0) + lantern_pool(p, 191.0);
	EMISSION = vec3(0.21, 0.10, 0.029) * pools * (0.35 + path * 0.65);
	ROUGHNESS = mix(0.96, 0.82, path);
	METALLIC = 0.0;
}
