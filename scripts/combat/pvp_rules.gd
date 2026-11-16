class_name PvpRules
extends RefCounted
## Regras de jogador contra jogador do lado do cliente ([JOGO-22]), só para não oferecer alvo que o servidor recusaria
## (quem decide é o servidor): até [constant MAX_LEVEL_GAP] níveis de diferença e ninguém em cima das pedras da praça.
## ATENÇÃO: = PVP_MAX_LEVEL_GAP e SAFE_ZONE_HALF em mmo-server/src/combat/pvp.ts.

## Maior diferença de nível para PvP.
const MAX_LEVEL_GAP: int = 10
## Metade do lado (m) da área segura (o quadrado de pedra da praça, 20 × 20 m no centro).
const SAFE_ZONE_HALF: float = 10.0


## O ponto (x, z) está em cima das pedras da praça (sem PvP)?
static func in_safe_zone(x: float, z: float) -> bool:
	return absf(x) <= SAFE_ZONE_HALF and absf(z) <= SAFE_ZONE_HALF


## [param me] pode atacar o jogador [param other] agora (nível e praça; grupo e PvP da zona a [Zone] confere)?
static func can_attack(me: PlayerState, other: PlayerState) -> bool:
	if me == null or other == null:
		return false
	if absi(me.level - other.level) > MAX_LEVEL_GAP:
		return false
	return not in_safe_zone(me.x, me.z) and not in_safe_zone(other.x, other.z)
