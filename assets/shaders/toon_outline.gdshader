// Contorno de anime para peça opaca ([ART-12]): ver toon_outline.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
#include "res://assets/shaders/toon_outline.gdshaderinc"

void fragment() {
	ALBEDO = outline_color(UV, COLOR).rgb * darkness;
}
