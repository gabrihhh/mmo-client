// Anime com recorte por alfa e duas faces ([ART-12]): cabelo, cílios e recortes do VRoid (material MASK). Ver
// toon.gdshaderinc.
shader_type spatial;
render_mode specular_disabled, cull_disabled;
#include "res://assets/shaders/toon.gdshaderinc"

// Pixel com alfa abaixo disso some.
uniform float alpha_cut = 0.5;

void fragment() {
	vec4 color = toon_color(UV, COLOR);
	if (color.a < alpha_cut) {
		discard;
	}
	ALBEDO = color.rgb;
}
