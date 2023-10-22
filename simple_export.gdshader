shader_type spatial;

const float shade_start = .7;
const float shade_stop = .5;
const float width = .03;


void fragment() {
	// Distance to the closedt integer.
	vec2 d_xy = abs(UV - round(UV));
	float d_z =  clamp(abs(UV.x + UV.y), 0, .5);
	// Distance to y = -x.
	float d = min(min(d_xy.x, d_xy.y), d_z);
	//       f^
	//     1 -|     +------
	//        |     |
	// start -|    ,+
	//        |  ,'
	//  stop -|-+
	//     0 ---------------> d
	float f = shade_stop + (1. - shade_start) * step(width, d) + smoothstep(0, width, d) * (shade_start - shade_stop);
	
	ALBEDO = COLOR.rgb * f;
}
