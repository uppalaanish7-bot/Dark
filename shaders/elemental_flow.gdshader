shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.15,0.7,1.0,1.0);
uniform float opacity = 0.65;
uniform float speed = 2.0;
uniform float stripes = 5.0;
uniform float distortion = 0.15;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 p) {
	vec2 cell=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(cell),hash21(cell+vec2(1,0)),f.x),mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),f.x),f.y);
}
void vertex() {
	VERTEX += NORMAL * sin(UV.y*18.0+UV.x*9.0-TIME*speed)*distortion;
}
void fragment() {
	vec2 scroll=UV*vec2(9.0,7.0)+vec2(TIME*speed*0.13,-TIME*speed*0.24);
	float turbulence=noise21(scroll)*0.7+noise21(scroll*2.1)*0.3;
	float flow = sin(UV.y*stripes*6.283 + UV.x*12.0 - TIME*speed*4.0 + turbulence*5.0);
	float small = noise21(scroll*4.0);
	float filaments = pow(max(0.0,flow*0.5+0.5),4.0);
	float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	float visibility = opacity * (0.04 + filaments*0.62 + small*small*0.15+rim*0.16);
	ALBEDO = mix(tint.rgb,tint.rgb*0.6+vec3(0.4),filaments*0.35) * visibility;
	ALPHA = 1.0;
}
