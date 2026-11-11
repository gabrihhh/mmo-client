class_name ItemAnimations
extends RefCounted
## ARQUIVO GERADO por mmo-docs/tools/gerar_catalogo_itens.py — não editar à mão ([ART-08]).
##
## Habilidade → pasta da animação própria dela dentro da pasta do item (res://assets/itens/<slot>/<nome>/animation-*).
## tools/characters/make_animations.gd lê <pasta>/male.glb e female.glb de cada uma e grava a animação na
## biblioteca do personagem como "skill_<abilityId>"; [method CharacterModel.play_ability] toca ela no lugar da
## genérica. ATENÇÃO: abilityIds de mmo-server/src/items/catalog.ts (regerar quando mudar).

## Prefixo do nome da animação própria na biblioteca do personagem.
const SKILL_PREFIX: String = "skill_"
## abilityId → pasta da animação própria (sem barra no fim).
const FOLDERS: Dictionary[String, String] = {
	"sword_attack": "res://assets/itens/hand/training-sword/animation-attack",
	"heavy_strike": "res://assets/itens/hand/training-sword/animation-skill-1",
	"dash": "res://assets/itens/hand/training-sword/animation-skill-2",
	"spin": "res://assets/itens/hand/training-sword/animation-skill-3",
	"staff_attack": "res://assets/itens/hand/training-staff/animation-attack",
	"fireball": "res://assets/itens/hand/training-staff/animation-skill-1",
	"meteor": "res://assets/itens/hand/training-staff/animation-skill-2",
	"bolt": "res://assets/itens/hand/training-staff/animation-skill-3",
	"heal": "res://assets/itens/head/training/animation-skill-1",
	"shield": "res://assets/itens/chest/training/animation-skill-1",
	"sprint": "res://assets/itens/boot/training/animation-skill-1",
	"arcane_attack": "res://assets/itens/hand/mage/animation-attack",
	"ice_lance": "res://assets/itens/hand/mage/animation-skill-1",
	"arcane_nova": "res://assets/itens/hand/mage/animation-skill-2",
	"starfall": "res://assets/itens/hand/mage/animation-skill-3",
	"meditation": "res://assets/itens/head/mage/animation-skill-1",
	"arcane_barrier": "res://assets/itens/chest/mage/animation-skill-1",
	"blink": "res://assets/itens/boot/mage/animation-skill-1",
	"knight_attack": "res://assets/itens/hand/knight/animation-attack",
	"line_cleave": "res://assets/itens/hand/knight/animation-skill-1",
	"heroic_charge": "res://assets/itens/hand/knight/animation-skill-2",
	"ground_slam": "res://assets/itens/hand/knight/animation-skill-3",
	"rallying_cry": "res://assets/itens/head/knight/animation-skill-1",
	"steel_wall": "res://assets/itens/chest/knight/animation-skill-1",
	"iron_stance": "res://assets/itens/boot/knight/animation-skill-1",
	"crossbow_attack": "res://assets/itens/hand/ranger/animation-attack",
	"piercing_bolt": "res://assets/itens/hand/ranger/animation-skill-1",
	"bolt_rain": "res://assets/itens/hand/ranger/animation-skill-2",
	"quick_shot": "res://assets/itens/hand/ranger/animation-skill-3",
	"bandage": "res://assets/itens/head/ranger/animation-skill-1",
	"leather_guard": "res://assets/itens/chest/ranger/animation-skill-1",
	"roll": "res://assets/itens/boot/ranger/animation-skill-1",
	"dagger_attack": "res://assets/itens/hand/assassin/animation-attack",
	"shadow_leap": "res://assets/itens/hand/assassin/animation-skill-1",
	"backstab": "res://assets/itens/hand/assassin/animation-skill-2",
	"blade_flurry": "res://assets/itens/hand/assassin/animation-skill-3",
	"evasion": "res://assets/itens/head/assassin/animation-skill-1",
	"smoke_veil": "res://assets/itens/chest/assassin/animation-skill-1",
	"shadow_step": "res://assets/itens/boot/assassin/animation-skill-1",
	"tome_attack": "res://assets/itens/hand/healer/animation-attack",
	"greater_heal": "res://assets/itens/hand/healer/animation-skill-1",
	"healing_circle": "res://assets/itens/hand/healer/animation-skill-2",
	"holy_shield": "res://assets/itens/hand/healer/animation-skill-3",
	"grace": "res://assets/itens/head/healer/animation-skill-1",
	"aegis": "res://assets/itens/chest/healer/animation-skill-1",
	"light_steps": "res://assets/itens/boot/healer/animation-skill-1",
}
