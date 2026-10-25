shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float intensity = 1.0;
uniform float seed = 0.0;
uniform bool ribbon = false;
uniform vec4 ember_color : source_color = vec4(1.0, 0.16, 0.015, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.83, 0.32, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1.0,0.0)), f.x), mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p)*0.57 + noise(p*2.07+13.7)*0.28 + noise(p*4.13)*0.15; }
void vertex() {
	float tip = 1.0 - UV.y;
	VERTEX.x += sin(TIME*8.0 + tip*7.0 + seed)*tip*tip*0.08;
}
void fragment() {
	vec2 p = vec2(UV.x, 1.0-UV.y);
	if (ribbon) { p.x *= 8.0; }
	float t = TIME*2.6 + seed;
	p.x += (fbm(vec2(p.y*4.0-t*0.4,seed+3.0))-0.5)*(0.18+p.y*0.38);
	float turbulence = fbm(vec2(p.x*4.0, p.y*3.5-t));
	float tongues = fbm(vec2(p.x*9.0+seed, p.y*5.0-t*1.4));
	float edge = abs(p.x-0.5)*2.0;
	float shape = ribbon ? 0.92-p.y*0.8 : 1.0-edge*(1.1+p.y*1.5)-p.y*0.66;
	float flame = smoothstep(0.2, 0.6, shape + turbulence*0.7 - tongues*0.55 - 0.12);
	float base = smoothstep(0.0, 0.07, p.y) * (1.0-smoothstep(0.83,1.0,p.y));
	float heat = clamp(shape*0.7 + turbulence*0.3 - p.y*0.6,0.0,1.0);
	float opacity = flame * base * intensity;
	opacity *= smoothstep(0.0,0.12,UV.x) * (1.0-smoothstep(0.88,1.0,UV.x));
	if (ribbon) { opacity *= smoothstep(0.0,0.055,UV.x) * (1.0-smoothstep(0.945,1.0,UV.x)); }
	// Mask additive radiance explicitly for the Compatibility renderer.
	// Otherwise the transparent parts of each crossed sheet glow as rectangles.
	ALBEDO = mix(ember_color.rgb, hot_color.rgb, pow(heat,1.5)) * opacity * 1.35;
	ALPHA = 1.0;
}
