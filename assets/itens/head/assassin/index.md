# Capuz sombrio (`assassin_hood`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Assassino · **Slot:** Cabeça (pasta `head/`) · **Vida extra:** +0
- **Descrição:** Capuz negro com máscara roxa.
- **No boneco:** assenta na cabeça pelo `head_item_offset`/`head_item_scale` da cena do personagem ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/head-assassin.tscn` | ×0,46, origem do modelo em (0; 0,21; 0) m | ✅ própria |
| Feminino | `female/head-assassin.tscn` | ×0,46, origem do modelo em (0; 0,21; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Evasão — pasta `animation-skill-1/`

- `evasion` · mira em você. Esquiva de quase tudo por um instante (recebe bem menos dano).
- Números: **Recebe 40% do dano** por 2,5 s · lançamento **instantâneo** · recarga **20 s** · mana **15**.
- Como funciona: Toque e sai, em você mesmo: faz você receber só 40% do dano por 2,5 s na hora.
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: só a animação. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/evasion.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
