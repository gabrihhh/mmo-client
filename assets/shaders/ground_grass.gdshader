// Chão de grama da zona ([MUN-04], GroundMaterial em scripts/world/ground_material.gd).
// Cor = a pintada no Blender (cor por vértice) × a textura de grama
// projetada de cima (coordenada do mundo X/Z: sem UV, sem esticar) × uma variação grande e suave (esconde a repetição).
// Barato para o celular: duas leituras da mesma textura, sem luz extra.
shader_type spatial;
render_mode cull_disabled;

/** Textura de grama (detalhe em volta do cinza médio; gerada por tools/world/make_grass_texture.gd). */
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
/** Metros que uma repetição da textura cobre no chão. */
uniform float tile_meters = 3.0;
/** Metros da variação grande (manchas claras/escuras que quebram a repetição). */
uniform float macro_meters = 41.0;
/** Força da variação grande (0 = nenhuma). */
uniform float macro_strength = 0.35;
/** Força do detalhe da textura (0 = chão liso). */
uniform float detail_strength = 1.0;
/**
 * Ajuste de cor por cima da pintada (1, 1, 1 = igual ao Blender). O verde do Blender é claro e, com a luz ambiente
 * azulada da cena, puxa para menta: um pouco menos de azul e de brilho deixa com cara de grama.
 */
uniform vec3 ground_tint : source_color = vec3(0.86, 0.9, 0.62);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	// source_color: a textura já chega em linear; o cinza médio (0,5 sRGB) vale ~0,214.
	vec3 detail = texture(grass_texture, world_position.xz / tile_meters).rgb / 0.214;
	detail = mix(vec3(1.0), detail, detail_strength);
	float macro = texture(grass_texture, world_position.xz / macro_meters + vec2(0.37, 0.71)).g / 0.214;
	ALBEDO = base * ground_tint * detail * mix(1.0, macro, macro_strength);
	ROUGHNESS = 0.95;
}
