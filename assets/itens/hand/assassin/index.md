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

- `dagger_attack` · mira no alvo. Golpe rápido de adaga no alvo.
- Números: **Dano 8** · alcance 2,2 m · lançamento **0,7 s** · recarga **0,7 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 0,7 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 2,2 m (+0,5 m de folga). Cada golpe tira 8 de vida depois de 0,7 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: clarão do golpe à frente (1,5 m) no momento do efeito. Animação: `attack_sword` (Meshy; genérica, também em 1 outra).
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,7 s = quadro 21** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Repete a cada **0,7 s**: a animação inteira deve terminar até **0,7 s = quadro 21** para emendar no próximo golpe.
  - Hoje usa a genérica `attack_sword`: dura 1,5 s (quadro 45), golpe em 0,87 s (quadro 26) → o jogo toca a **×1,24** para o golpe cair em 0,7 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_dagger_attack`).

### Habilidade 1: Salto sombrio — pasta `animation-skill-1/`

- `shadow_leap` · mira direção (linha). Salta até o inimigo num instante.
- Números: **Avança 9 m** em 0,2 s · alcance 9 m · meia-largura 0,6 m · lançamento **instantâneo** · recarga **14 s** · mana **10**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 9 m na direção, percorrendo o caminho em 0,2 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 9 m de comprimento × 1,2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 4 outras).
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
- Os outros veem: clarão do golpe à frente (1,8 m) no momento do efeito. Animação: `heavy_strike` (Meshy; genérica, também em 3 outras).
- Desenho da carta: ✅ `assets/icons/abilities/backstab.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,2 s = quadro 6** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 14 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `heavy_strike`: dura 1,53 s (quadro 46), golpe em 1,23 s (quadro 37) → o jogo toca a **×4** para o golpe cair em 0,2 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_backstab`).

### Habilidade 3: Dança das lâminas — pasta `animation-skill-3/`

- `blade_flurry` · mira ao redor de você. Rodopia com as adagas e corta todos em volta.
- Números: **Dano 40** · raio 2,5 m · lançamento **0,3 s** · recarga **16 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,3 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 2,5 m: tira 40 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 2,5 m no momento do efeito. Animação: `spin` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/blade_flurry.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,3 s = quadro 9** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 16 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `spin`: dura 1,5 s (quadro 45), golpe em 0,9 s (quadro 27) → o jogo toca a **×3** para o golpe cair em 0,3 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_blade_flurry`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
