// Contorno neon do item melhorado ([JOGO-17]): casca um pouco maior que a peça, desenhada só pelo lado de dentro
// (cull_front), sem luz e na cor do brilho: vira uma linha acesa em volta da silhueta, e a peça continua aparecendo.
// Encadeada como next_pass do item_glow (material_overlay).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.6, 0.2, 1.0);
// Espessura (m) do contorno.
uniform float width = 0.006;
// Fração que pulsa e velocidade (rad/s), igual ao brilho de dentro.
uniform float pulse = 0.12;
uniform float pulse_speed = 2.5;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	float beat = 1.0 - pulse + pulse * sin(TIME * pulse_speed);
	ALBEDO = glow_color * beat;
}
