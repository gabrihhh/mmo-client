# Cajado de treino (`training_staff`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Treino · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Cajado de madeira simples para as primeiras magias.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-training-staff.tscn` | ×1 (cena sem transformação) | ⚠ placeholder gerado por código (`assets/placeholders/staff.glb`) |
| Feminino | `female/hand-training-staff.tscn` | ×1 (cena sem transformação) | ⚠ placeholder gerado por código (`assets/placeholders/staff.glb`) |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Ataque — pasta `animation-attack/`

- `staff_attack` · mira no alvo. Faísca mágica no alvo.
- Números: **Dano 7** · alcance 8 m · lançamento **1,2 s** · recarga **1,2 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 1,2 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 8 m (+0,5 m de folga). Cada golpe tira 7 de vida depois de 1,2 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: projétil visual que sai da mão e chega junto com o dano. Animação: `attack_staff` (Meshy; genérica, também em 2 outras).
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1,2 s = quadro 36** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil visual **sai da mão em 0,9 s = quadro 27** (voa 0,3 s até o alvo).
  - Repete a cada **1,2 s**: a animação inteira deve terminar até **1,2 s = quadro 36** para emendar no próximo golpe.
  - Hoje usa a genérica `attack_staff`: dura 1,1 s (quadro 33), golpe em 0,47 s (quadro 14) → o jogo toca a **×0,39** para o golpe cair em 1,2 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_staff_attack`).

### Habilidade 1: Bola de fogo — pasta `animation-skill-1/`

- `fireball` · mira direção (linha). Projétil de fogo que acerta o primeiro no caminho (dá para desviar).
- Números: **Dano 20** · alcance 12 m · meia-largura 0,6 m · projétil 14 m/s (dá para desviar) · lançamento **0,6 s** · recarga **4 s** · mana **15**.
- Como funciona: Arraste para apontar a linha (toque = na direção do alvo fixo ou para a frente) e solte; depois de 0,6 s de lançamento (andar nesse tempo cancela), um projétil a 14 m/s acerta o PRIMEIRO inimigo no caminho (até 12 m): tira 20 de vida.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 12 m de comprimento × 1,2 m de largura.
- Os outros veem: brilho na mão durante o lançamento; aviso no chão (faixa) até o efeito; projétil voando de verdade. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/fireball.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,6 s = quadro 18** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil de verdade sai no momento do efeito (14 m/s).
  - Recarga 4 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_forward`: dura 1,5 s (quadro 45), golpe em 0,9 s (quadro 27) → o jogo toca a **×1,5** para o golpe cair em 0,6 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_fireball`).

### Habilidade 2: Meteoro — pasta `animation-skill-2/`

- `meteor` · mira área num ponto. Meteoro cai no ponto escolhido e queima todos na área.
- Números: **Dano 30** · alcance 10 m · raio 2,5 m · lançamento **1 s** · recarga **12 s** · mana **30**.
- Como funciona: Arraste para pôr o círculo no chão (até 10 m; toque = no alvo fixo ou à frente) e solte; depois de 1 s de lançamento (andar nesse tempo cancela), todos os inimigos dentro do raio de 2,5 m: tira 30 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m no ponto do dedo (até 10 m), com a linha até ele.
- Os outros veem: brilho na mão durante o lançamento; aviso no chão (círculo) até o efeito. Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/meteor.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1 s = quadro 30** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 12 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×1,6** para o golpe cair em 1 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_meteor`).

### Habilidade 3: Raio — pasta `animation-skill-3/`

- `bolt` · mira no alvo. Raio rápido no alvo.
- Números: **Dano 18** · alcance 10 m · lançamento **0,4 s** · recarga **7 s** · mana **12**.
- Como funciona: Com alvo fixo, um toque lança nele; sem alvo, arraste até um inimigo e solte. O alvo precisa estar a até 10 m no fim; tira 18 de vida depois de 0,4 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento; projétil visual que sai da mão e chega junto com o dano. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/bolt.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,4 s = quadro 12** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil visual **sai da mão em 0,25 s = quadro 8** (voa 0,15 s até o alvo).
  - Recarga 7 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_forward`: dura 1,5 s (quadro 45), golpe em 0,9 s (quadro 27) → o jogo toca a **×2,25** para o golpe cair em 0,4 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_bolt`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
