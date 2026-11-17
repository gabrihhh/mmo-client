// Sombreado de anime dos personagens e itens vestidos ([ART-12], [ToonMaterials]): em vez da luz suave do PBR, a
// luz do sol vira 2 tons — iluminado e sombra — com uma borda curta entre eles (cel shading). Sem brilho especular.
// A cor vem da textura/cor do material original (convertido por ToonMaterials); a luz ambiente do mundo continua
// clareando o lado da sombra. Incluído por toon.gdshader (opaco) e toon_cutout.gdshader (recorte por alfa, duas
// faces). O contorno é outra passada (toon_outline*.gdshader, next_pass).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
// true: multiplica pela cor dos vértices (peças geradas por código, LowPolyBuilder).
uniform bool use_vertex_color = false;
// Onde a luz vira sombra (cosseno entre a normal e o sol; 0 = de lado) e meia largura da borda entre os tons.
uniform float shade_threshold = 0.05;
uniform float shade_softness = 0.04;
// Luz do sol (fração da cor do sol) no lado iluminado e no lado da sombra. Somadas à ambiente do mundo (~0,5 na
// zona 1) dão ~1,0 no iluminado (a cor da textura, como no VRoid) e ~0,65 na sombra. Com o sol inteiro a pele clara
// do VRoid estourava para branco.
uniform float lit_strength = 0.55;
uniform float shade_floor = 0.15;

vec4 toon_color(vec2 uv, vec4 vertex_color) {
	vec4 color = texture(albedo_texture, uv) * albedo_color;
	return use_vertex_color ? color * vertex_color : color;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, facing);
	// A sombra projetada (ATTENUATION) também vira degrau, para não borrar.
	lit *= step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_floor, lit_strength, lit) / PI;
}
