# Tiara da luz (`healer_circlet`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Curandeiro · **Slot:** Cabeça (pasta `head/`) · **Vida extra:** +0
- **Descrição:** Tiara dourada com véu branco.
- **No boneco:** assenta na cabeça pelo `head_item_offset`/`head_item_scale` da cena do personagem ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/head-healer.tscn` | ×0,235, origem do modelo em (0; 0,25; 0) m | ✅ própria |
| Feminino | `female/head-healer.tscn` | ×0,235, origem do modelo em (0; 0,25; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Graça — pasta `animation-skill-1/`

- `grace` · mira em você. Recebe menos dano por alguns segundos.
- Números: **Recebe 60% do dano** por 4 s · lançamento **instantâneo** · recarga **18 s** · mana **15**.
- Como funciona: Toque e sai, em você mesmo: faz você receber só 60% do dano por 4 s na hora.
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: só a animação. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/grace.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Instantânea:** o efeito acontece no toque (quadro 0); a animação acompanha o efeito, sem preparação.
  - Recarga 18 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `buff`: dura 1,5 s (quadro 45), golpe em 0,57 s (quadro 17).
  - Toca sempre na velocidade normal (×1): a duração é livre, mas curta (o personagem já pode agir).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
