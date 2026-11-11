# Capuz do atirador (`ranger_hood`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Atirador · **Slot:** Cabeça (pasta `head/`) · **Vida extra:** +0
- **Descrição:** Capuz verde de caçador.
- **No boneco:** assenta na cabeça pelo `head_item_offset`/`head_item_scale` da cena do personagem ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/head-ranger.tscn` | ×0,46, origem do modelo em (0; 0,22; 0) m | ✅ própria |
| Feminino | `female/head-ranger.tscn` | ×0,46, origem do modelo em (0; 0,22; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Curativo — pasta `animation-skill-1/`

- `bandage` · mira em você. Faz um curativo rápido e recupera vida.
- Números: **Cura 25** · lançamento **1 s** · recarga **16 s** · mana **15**.
- Como funciona: Toque e sai, em você mesmo: cura 25 depois de 1 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: brilho na mão durante o lançamento. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/bandage.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
