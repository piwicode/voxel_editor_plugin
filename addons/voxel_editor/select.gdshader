shader_type spatial;
render_mode unshaded;

uniform vec3 pick_normal = vec3(1.,0.,0.);

void fragment() {
	ALBEDO = vec3(.1, .1, 1.);
	ALPHA = dot(mat3(INV_VIEW_MATRIX) * NORMAL, pick_normal);
	// Avoid z-fighting.
	DEPTH = FRAGCOORD.z - .000001;
}
