// Brilho de item melhorado ([JOGO-17]): passada extra por cima da peça (material_overlay), somando luz na cor do
// conjunto. Mais forte nas bordas (fresnel: contorno tipo neon), um pouco no meio e pulsando devagar. A malha cresce
// uns milímetros pela normal para o brilho não brigar com a superfície. Funciona em peça presa ao osso e em roupa
// com pesos (o skinning já vem aplicado antes do vertex()).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.6, 0.2, 1.0);
// Quanto do brilho fica no meio da peça (0 = só contorno).
uniform float fill = 0.1;
// Potência do contorno (maior = contorno mais fino).
uniform float rim_power = 2.0;
// Intensidade geral.
uniform float energy = 1.0;
// Fração do brilho que pulsa e a velocidade (rad/s).
uniform float pulse = 0.15;
uniform float pulse_speed = 2.5;
// Quanto (m) a casca cresce pela normal.
uniform float grow = 0.004;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float beat = 1.0 - pulse + pulse * sin(TIME * pulse_speed);
	ALBEDO = glow_color * (fill + rim) * energy * beat;
}
