# Sapatilhas arcanas (`mage_shoes`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Mago · **Slot:** Pés (pasta `boot/`) · **Vida extra:** +0
- **Descrição:** Sapatilhas de seda que dobram o espaço.
- **No boneco:** encaixe automático pelo pé de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/boot-mage.tscn` | ×(0,366; 0,35; 0,334), origem do modelo em (0,01; -0,05; 0,08) m | ✅ própria |
| Feminino | `female/boot-mage.tscn` | ×(0,366; 0,35; 0,334), origem do modelo em (0,01; -0,05; 0,08) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Teleporte — pasta `animation-skill-1/`

- `blink` · mira direção (linha). Some e reaparece alguns metros à frente.
- Números: **Avança 7 m** em 0,1 s · alcance 7 m · meia-largura 0,6 m · lançamento **instantâneo** · recarga **10 s** · mana **15**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 7 m na direção, percorrendo o caminho em 0,1 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 7 m de comprimento × 1,2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/blink.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
