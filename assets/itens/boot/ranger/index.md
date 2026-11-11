# Botas de caçador (`ranger_boots`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Atirador · **Slot:** Pés (pasta `boot/`) · **Vida extra:** +0
- **Descrição:** Botas altas de couro para terreno difícil.
- **No boneco:** encaixe automático pelo pé de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/boot-ranger.tscn` | ×1, origem do modelo em (0; 0; 0) m | ✅ própria |
| Feminino | `female/boot-ranger.tscn` | ×1, origem do modelo em (0; 0; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Rolamento — pasta `animation-skill-1/`

- `roll` · mira direção (linha). Rola alguns metros para fugir de perto.
- Números: **Avança 5 m** em 0,25 s · alcance 5 m · meia-largura 0,6 m · lançamento **instantâneo** · recarga **9 s** · mana **10**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 5 m na direção, percorrendo o caminho em 0,25 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 5 m de comprimento × 1,2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/roll.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Instantânea:** o efeito acontece no toque (quadro 0); a animação acompanha o efeito, sem preparação.
  - O deslocamento dura **0,25 s = quadro 8** (5 m): o movimento do corpo deve caber nisso (o jogo move o personagem; a animação fica no lugar).
  - Recarga 9 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `dash`: dura 1,8 s (quadro 54), sem momento de golpe (toca na velocidade normal).
  - Toca sempre na velocidade normal (×1): a duração é livre, mas curta (o personagem já pode agir).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
