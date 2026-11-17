// Contorno de anime para peça com recorte por alfa ([ART-12]): some onde a peça some. Ver toon_outline.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
#include "res://assets/shaders/toon_outline.gdshaderinc"

uniform float alpha_cut = 0.5;

void fragment() {
	vec4 color = outline_color(UV, COLOR);
	if (color.a < alpha_cut) {
		discard;
	}
	ALBEDO = color.rgb * darkness;
}
