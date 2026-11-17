// Anime opaco ([ART-12]): ver toon.gdshaderinc. Sem discard (o celular desenha mais rápido).
shader_type spatial;
render_mode specular_disabled, cull_back;
#include "res://assets/shaders/toon.gdshaderinc"

void fragment() {
	ALBEDO = toon_color(UV, COLOR).rgb;
}
