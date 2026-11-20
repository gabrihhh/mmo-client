# Adagas gêmeas (`assassin_daggers`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Assassino · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Par de adagas curvas. Golpes rápidos e cartas fortes, mas que demoram a voltar.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-assassin.tscn` | ×0,42, origem do modelo em (0; 0,14; 0) m | ✅ própria |
| Feminino | `female/hand-assassin.tscn` | ×0,42, origem do modelo em (0; 0,14; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Ataque — pasta `animation-attack/`

- `dagger_attack` · mira direção (linha). Estocada com um passo à frente (um alvo).
- Números: **Dano 4** · **Avança 1 m** em 0,15 s · alcance 2,2 m · leque **45°** · **1 alvo** · sai na hora · execução **0,35 s** · sem mana.
- Como funciona: Toque no ⚔: golpe na direção do **inimigo mais perto** (ou para a frente). Arrastar mostra o formato do golpe na direção do dedo e solta ao largar. Sem carregamento: o golpe sai na hora — dá um passo de 1 m na direção e golpeia em leque de 45° com 2,2 m de alcance centrado na direção: acerta o inimigo mais perto dentro dele (tira 4 de vida, leva você 1 m na direção, percorrendo o caminho em 0,15 s). Depois, 0,35 s de execução em que outro golpe não sai. Dá para andar batendo.
- Ao segurar (prévia): leque dourado translúcido de 45° e 2,2 m saindo do personagem na direção do dedo.
- Os outros veem: o personagem virado para a direção do golpe; clarão do leque (45°, 2,2 m) na hora do golpe. Animação: `attack_daggers` (Meshy; genérica, também em 1 outra).
- **Tempo da animação (Blender, 30 fps):**
  - **Sai na hora** (sem carregamento): o jogo toca a animação acelerada para o golpe cair a ~0,15 s do toque.
  - Tempo de execução **0,35 s = quadro 10**: a animação inteira deve caber nisso para emendar no próximo golpe (o jogador pode tocar de novo assim que acabar).
  - O passo dura **0,15 s = quadro 4** (1 m): o jogo move o personagem; a animação fica no lugar.

### Habilidade 1: Salto sombrio — pasta `animation-skill-1/`

- `shadow_leap` · mira direção (linha). Salta até o inimigo num instante.
- Números: **Avança 9 m** em 0,2 s · alcance 9 m · meia-largura 0,6 m · lançamento **instantâneo** · recarga **14 s** · mana **10**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 9 m na direção, percorrendo o caminho em 0,2 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 9 m de comprimento × 1,2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 3 outras).
- Desenho da carta: ✅ `assets/icons/abilities/shadow_leap.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Instantânea:** o efeito acontece no toque (quadro 0); a animação acompanha o efeito, sem preparação.
  - O deslocamento dura **0,2 s = quadro 6** (9 m): o movimento do corpo deve caber nisso (o jogo move o personagem; a animação fica no lugar).
  - Recarga 14 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `dash`: dura 1,8 s (quadro 54), sem momento de golpe (toca na velocidade normal).
  - Toca sempre na velocidade normal (×1): a duração é livre, mas curta (o personagem já pode agir).

### Habilidade 2: Apunhalar — pasta `animation-skill-2/`

- `backstab` · mira no alvo. Golpe muito forte no alvo, de perto.
- Números: **Dano 50** · alcance 2,5 m · lançamento **0,2 s** · recarga **14 s** · mana **15**.
- Como funciona: Com alvo fixo, um toque lança nele; sem alvo, arraste até um inimigo e solte. O alvo precisa estar a até 2,5 m no fim; tira 50 de vida depois de 0,2 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: clarão do golpe à frente (1,8 m) no momento do efeito. Animação: `attack_daggers` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/backstab.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,2 s = quadro 6** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 14 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `attack_daggers`: dura 1,4 s (quadro 42), golpe em 1 s (quadro 30) → o jogo toca a **×4** para o golpe cair em 0,2 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_backstab`).

### Habilidade 3: Dança das lâminas — pasta `animation-skill-3/`

- `blade_flurry` · mira ao redor de você. Rodopia com as adagas e corta todos em volta.
- Números: **Dano 40** · raio 2,5 m · lançamento **0,3 s** · recarga **16 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,3 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 2,5 m: tira 40 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 2,5 m no momento do efeito. Animação: `spin` (Meshy; própria).
- Desenho da carta: ✅ `assets/icons/abilities/blade_flurry.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,3 s = quadro 9** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 16 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `spin`: dura 1,5 s (quadro 45), golpe em 0,9 s (quadro 27) → o jogo toca a **×3** para o golpe cair em 0,3 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_blade_flurry`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
