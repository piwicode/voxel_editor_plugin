shader_type spatial;
render_mode unshaded;

uniform vec3 pick_normal = vec3(1.,0.,0.);

void fragment() {
	ALBEDO = vec3(.1, .1, 1.);
	// Test wether the face normal is aligned with the pick normal.
	float d = dot(mat3(INV_VIEW_MATRIX) * NORMAL, pick_normal);
	// Highlight if:
	// d * .8 > .5
	// d > .5 / .8 = .625
	ALPHA = max(0., round(d * .8));
	// Avoid z-fighting.
	DEPTH = FRAGCOORD.z - .000001;
}
