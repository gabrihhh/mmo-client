class_name DeathFall
extends RefCounted
## Queda ao morrer ([JOGO-05]): o corpo tomba para trás em volta dos pés, fica um instante no chão e some até
## renascer. Visual só — morte e renascimento são do servidor. Usado por jogadores e bonecos de treino.

## Tempo (s) da queda e quanto tempo (s, desde a morte) o corpo fica visível.
const FALL_SECONDS: float = 0.45
const VISIBLE_SECONDS: float = 1.5

## Segundos desde a morte (-1 = vivo).
var dead_for: float = -1.0


## Atualiza [param body] (o nó "Body", com origem nos pés) para o estado [param dead].
func update(body: Node3D, dead: bool, delta: float) -> void:
	if not dead:
		if dead_for >= 0.0:
			dead_for = -1.0
			body.visible = true
			body.rotation.x = 0.0
		return
	if dead_for < 0.0:
		dead_for = 0.0
	dead_for += delta
	var t: float = clampf(dead_for / FALL_SECONDS, 0.0, 1.0)
	body.rotation.x = -t * t * PI * 0.5  # acelera como quem cai
	body.visible = dead_for < VISIBLE_SECONDS


## true enquanto morto (o corpo não deve receber outros efeitos, como o balanço).
func is_dead() -> bool:
	return dead_for >= 0.0
