# Grevas do cavaleiro (`knight_greaves`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Cavaleiro · **Slot:** Pés (pasta `boot/`) · **Vida extra:** +40
- **Descrição:** Botas de placas de aço.
- **No boneco:** encaixe automático pelo pé de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/boot-knight.tscn` | ×(0,39; 0,357; 0,356), origem do modelo em (0,01; 0,04; 0,08) m | ✅ própria |
| Feminino | `female/boot-knight.tscn` | ×(0,39; 0,357; 0,356), origem do modelo em (0,01; 0,04; 0,08) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Pés de ferro — pasta `animation-skill-1/`

- `iron_stance` · mira em você. Firma os pés e recebe metade do dano por um tempo.
- Números: **Recebe 50% do dano** por 4 s · lançamento **instantâneo** · recarga **16 s** · mana **15**.
- Como funciona: Toque e sai, em você mesmo: faz você receber só 50% do dano por 4 s na hora.
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: só a animação. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/iron_stance.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Instantânea:** o efeito acontece no toque (quadro 0); a animação acompanha o efeito, sem preparação.
  - Recarga 16 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `buff`: dura 1,5 s (quadro 45), golpe em 0,57 s (quadro 17).
  - Toca sempre na velocidade normal (×1): a duração é livre, mas curta (o personagem já pode agir).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
