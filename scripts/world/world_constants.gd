class_name WorldConstants
extends RefCounted
## Constantes do mundo compartilhadas entre scripts. Ver mmo-docs [MUN-01..03].

## Metade do lado da Zone 1 (300 m × 300 m centrada na origem).
## Precisa bater com ZONE_HALF_SIZE em mmo-server/src/rooms/ZoneRoom.ts.
const ZONE_HALF_SIZE: float = 150.0

## Altura do personagem, em metros.
const CHARACTER_HEIGHT: float = 1.8
## Raio da cápsula de colisão do personagem, em metros.
const CHARACTER_RADIUS: float = 0.4
