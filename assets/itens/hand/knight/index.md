# Espada longa (`knight_sword`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Cavaleiro · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Espada reta de aço com guarda dourada. Bate pouco, mas segura a linha de frente.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-knight.tscn` | ×1,05, origem do modelo em (0; 0,33; 0) m | ✅ própria |
| Feminino | `female/hand-knight.tscn` | ×1,05, origem do modelo em (0; 0,33; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Ataque — pasta `animation-attack/`

- `knight_attack` · mira direção (linha). Espada longa em leque de 90° à frente: acerta todos dentro.
- Números: **Dano 4** · alcance 2,8 m · leque **90°** · sai na hora · execução **0,65 s** · sem mana.
- Como funciona: Toque no ⚔: golpe na direção do **inimigo mais perto** (ou para a frente). Arrastar mostra o formato do golpe na direção do dedo e solta ao largar. Sem carregamento: o golpe sai na hora — leque de 90° com 2,8 m de alcance centrado na direção: acerta todos os inimigos dentro dele (tira 4 de vida). Depois, 0,65 s de execução em que outro golpe não sai. Dá para andar batendo.
- Ao segurar (prévia): leque dourado translúcido de 90° e 2,8 m saindo do personagem na direção do dedo.
- Os outros veem: o personagem virado para a direção do golpe; clarão do leque (90°, 2,8 m) na hora do golpe. Animação: `attack_greatsword` (Mixamo; própria).
- **Tempo da animação (Blender, 30 fps):**
  - **Sai na hora** (sem carregamento): o jogo toca a animação acelerada para o golpe cair a ~0,15 s do toque.
  - Tempo de execução **0,65 s = quadro 20**: a animação inteira deve caber nisso para emendar no próximo golpe (o jogador pode tocar de novo assim que acabar).

### Habilidade 1: Corte em linha — pasta `animation-skill-1/`

- `line_cleave` · mira direção (linha). Corte largo à frente que acerta o primeiro inimigo.
- Números: **Dano 14** · alcance 4 m · meia-largura 1,2 m · lançamento **0,5 s** · recarga **7 s** · mana **12**.
- Como funciona: Arraste para apontar a linha (toque = na direção do alvo fixo ou para a frente) e solte; depois de 0,5 s de lançamento (andar nesse tempo cancela), acerta na hora o PRIMEIRO inimigo na linha (até 4 m): tira 14 de vida.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 4 m de comprimento × 2,4 m de largura.
- Os outros veem: aviso no chão (faixa) até o efeito; clarão do golpe à frente (3 m) no momento do efeito. Animação: `heavy_strike` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/line_cleave.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,5 s = quadro 15** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 7 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `heavy_strike`: dura 1,53 s (quadro 46), golpe em 1,23 s (quadro 37) → o jogo toca a **×2,46** para o golpe cair em 0,5 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_line_cleave`).

### Habilidade 2: Avanço heroico — pasta `animation-skill-2/`

- `heroic_charge` · mira direção (linha). Avança longe na direção escolhida.
- Números: **Avança 8 m** em 0,4 s · alcance 8 m · meia-largura 1 m · lançamento **instantâneo** · recarga **10 s** · mana **12**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 8 m na direção, percorrendo o caminho em 0,4 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 8 m de comprimento × 2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 3 outras).
- Desenho da carta: ✅ `assets/icons/abilities/heroic_charge.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Instantânea:** o efeito acontece no toque (quadro 0); a animação acompanha o efeito, sem preparação.
  - O deslocamento dura **0,4 s = quadro 12** (8 m): o movimento do corpo deve caber nisso (o jogo move o personagem; a animação fica no lugar).
  - Recarga 10 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `dash`: dura 1,8 s (quadro 54), sem momento de golpe (toca na velocidade normal).
  - Toca sempre na velocidade normal (×1): a duração é livre, mas curta (o personagem já pode agir).

### Habilidade 3: Desafio — pasta `animation-skill-3/`

- `challenge` · mira ao redor de você. Desafia os monstros em volta: eles atacam só você por um tempo.
- Números: **Provoca** por 4 s · raio 6 m · lançamento **0,5 s** · recarga **12 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,5 s de lançamento (andar nesse tempo cancela), todos os monstros inimigos em volta num raio de 6 m: provoca: atacam só você por 4 s e sua ameaça neles vira 110% da maior ([JOGO-14]).
- Ao segurar (prévia): círculo dourado translúcido de raio 6 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 6 m no momento do efeito. Animação: `heavy_strike` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/challenge.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,5 s = quadro 15** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 12 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `heavy_strike`: dura 1,53 s (quadro 46), golpe em 1,23 s (quadro 37) → o jogo toca a **×2,46** para o golpe cair em 0,5 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_challenge`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
