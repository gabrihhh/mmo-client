// Contorno de anime ([ART-12], [ToonMaterials]): casca um pouco maior que a peça, desenhada só pelo lado de dentro
// (cull_front), sem luz, na cor da peça escurecida: vira uma linha escura em volta da silhueta. A casca cresce no
// espaço da câmera, então a espessura é a mesma em metros mesmo em item escalado/esticado. Encadeado como next_pass
// do material toon. Incluído por toon_outline.gdshader e toon_outline_cutout.gdshader.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
// Espessura (m) do contorno.
uniform float width = 0.012;
// Cor do contorno = cor da peça × isto (0 = preto).
uniform float darkness = 0.18;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_position.xyz += view_normal * width;
	POSITION = PROJECTION_MATRIX * view_position;
}

vec4 outline_color(vec2 uv, vec4 vertex_color) {
	vec4 color = texture(albedo_texture, uv) * albedo_color;
	return use_vertex_color ? color * vertex_color : color;
}
