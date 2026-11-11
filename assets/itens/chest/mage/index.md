# Túnica arcana (`mage_tunic`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Mago · **Slot:** Peito (pasta `chest/`) · **Vida extra:** +0
- **Descrição:** Túnica azul com runa arcana e faixa roxa.
- **No boneco:** encaixe automático no tronco de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/chest-mage.tscn` | ×0,82, origem do modelo em (0; -0,39; 0) m | ✅ própria |
| Feminino | `female/chest-mage.tscn` | ×0,82, origem do modelo em (0; -0,39; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Barreira arcana — pasta `animation-skill-1/`

- `arcane_barrier` · mira em você. Barreira mágica que absorve dano.
- Números: **Escudo 40** por 5 s · lançamento **0,3 s** · recarga **18 s** · mana **25**.
- Como funciona: Toque e sai, em você mesmo: dá um escudo que absorve 40 de dano por 5 s depois de 0,3 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: brilho na mão durante o lançamento. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/arcane_barrier.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
