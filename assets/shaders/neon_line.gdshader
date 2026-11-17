// Linha neon no chão (zonas de nível, [JOGO-22] / RegionLines): miolo claro no meio + auréola na cor da zona que vai
// até a borda da faixa sem apagar (a linha da zona vizinha encosta nela). Somada à cor do chão (blend_add = "acende"
// sem precisar de glow na tela, que o renderer mobile pagaria caro). Uma pulsação leve corre ao longo da linha.
// Entrada da malha: COLOR = cor da zona; UV.x = 0..1 de uma borda da faixa à outra; UV.y = metros ao longo da linha.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Metade da largura do miolo, em fração da meia-faixa (0..1).
uniform float core = 0.3;
// Quanto da auréola ainda acende na borda da faixa (0 = apaga, 1 = igual ao meio).
uniform float halo_edge = 0.35;
// Força da auréola e quão rápido ela some para as bordas (maior = mais fechada).
uniform float halo_strength = 1.1;
uniform float halo_falloff = 2.6;
// Pulsação: amplitude (0..1), velocidade (rad/s) e comprimento da onda ao longo da linha (m).
uniform float pulse_amount = 0.22;
uniform float pulse_speed = 2.4;
uniform float pulse_length = 6.0;

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float core_mask = 1.0 - smoothstep(core * 0.5, core, d);
	float halo = mix(halo_edge, 1.0, pow(max(1.0 - d, 0.0), halo_falloff)) * halo_strength;
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(TIME * pulse_speed - UV.y * 6.2831 / pulse_length);
	vec3 hot = mix(COLOR.rgb, vec3(1.0), 0.3);
	ALBEDO = (COLOR.rgb * halo + hot * core_mask) * pulse;
}
