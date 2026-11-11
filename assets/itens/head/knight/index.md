# Elmo do cavaleiro (`knight_helm`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Cavaleiro · **Slot:** Cabeça (pasta `head/`) · **Vida extra:** +40
- **Descrição:** Elmo de aço com crista azul.
- **No boneco:** assenta na cabeça pelo `head_item_offset`/`head_item_scale` da cena do personagem ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/head-knight.tscn` | ×0,44, origem do modelo em (0; 0,21; 0) m | ✅ própria |
| Feminino | `female/head-knight.tscn` | ×0,44, origem do modelo em (0; 0,21; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Grito de proteção — pasta `animation-skill-1/`

- `rallying_cry` · mira ao redor de você. Escudo em você e nos aliados em volta.
- Números: **Escudo 25** por 5 s · raio 4 m · lançamento **0,3 s** · recarga **18 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,3 s de lançamento (andar nesse tempo cancela), todos os aliados (e você) em volta num raio de 4 m: dá um escudo que absorve 25 de dano por 5 s.
- Ao segurar (prévia): círculo dourado translúcido de raio 4 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/rallying_cry.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
