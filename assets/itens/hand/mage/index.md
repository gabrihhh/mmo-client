# Cajado arcano (`arcane_staff`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Mago · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Cajado retorcido com um cristal arcano. Dano constante de longe.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-mage.tscn` | ×1,677, origem do modelo em (0; 0,37; 0) m | ✅ própria |
| Feminino | `female/hand-mage.tscn` | ×1,677, origem do modelo em (0; 0,37; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Ataque — pasta `animation-attack/`

- `arcane_attack` · mira no alvo. Faísca arcana no alvo.
- Números: **Dano 9** · alcance 9 m · lançamento **1,1 s** · recarga **1,1 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 1,1 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 9 m (+0,5 m de folga). Cada golpe tira 9 de vida depois de 1,1 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: projétil visual que sai da mão e chega junto com o dano. Animação: `attack_staff` (Meshy; genérica, também em 2 outras).
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1,1 s = quadro 33** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil visual **sai da mão em 0,8 s = quadro 24** (voa 0,3 s até o alvo).
  - Repete a cada **1,1 s**: a animação inteira deve terminar até **1,1 s = quadro 33** para emendar no próximo golpe.
  - Hoje usa a genérica `attack_staff`: dura 1,1 s (quadro 33), golpe em 0,47 s (quadro 14) → o jogo toca a **×0,43** para o golpe cair em 1,1 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_arcane_attack`).

### Habilidade 1: Lança de gelo — pasta `animation-skill-1/`

- `ice_lance` · mira direção (linha). Lança de gelo rápida que acerta o primeiro no caminho.
- Números: **Dano 20** · alcance 14 m · meia-largura 0,4 m · projétil 20 m/s (dá para desviar) · lançamento **0,5 s** · recarga **4 s** · mana **15**.
- Como funciona: Arraste para apontar a linha (toque = na direção do alvo fixo ou para a frente) e solte; depois de 0,5 s de lançamento (andar nesse tempo cancela), um projétil a 20 m/s acerta o PRIMEIRO inimigo no caminho (até 14 m): tira 20 de vida.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 14 m de comprimento × 0,8 m de largura.
- Os outros veem: brilho na mão durante o lançamento; aviso no chão (faixa) até o efeito; projétil voando de verdade. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/ice_lance.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,5 s = quadro 15** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil de verdade sai no momento do efeito (20 m/s).
  - Recarga 4 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_forward`: dura 1,5 s (quadro 45), golpe em 0,9 s (quadro 27) → o jogo toca a **×1,8** para o golpe cair em 0,5 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_ice_lance`).

### Habilidade 2: Nova arcana — pasta `animation-skill-2/`

- `arcane_nova` · mira ao redor de você. Explosão arcana que acerta todos ao seu redor.
- Números: **Dano 18** · raio 4 m · lançamento **0,6 s** · recarga **8 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,6 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 4 m: tira 18 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 4 m em volta do personagem.
- Os outros veem: brilho na mão durante o lançamento; **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/arcane_nova.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,6 s = quadro 18** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 8 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×2,67** para o golpe cair em 0,6 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_arcane_nova`).

### Habilidade 3: Chuva de estrelas — pasta `animation-skill-3/`

- `starfall` · mira área num ponto. Estrelas caem numa área grande, longe de você.
- Números: **Dano 24** · alcance 12 m · raio 3 m · lançamento **1,2 s** · recarga **10 s** · mana **25**.
- Como funciona: Arraste para pôr o círculo no chão (até 12 m; toque = no alvo fixo ou à frente) e solte; depois de 1,2 s de lançamento (andar nesse tempo cancela), todos os inimigos dentro do raio de 3 m: tira 24 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 3 m no ponto do dedo (até 12 m), com a linha até ele.
- Os outros veem: brilho na mão durante o lançamento; aviso no chão (círculo) até o efeito. Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/starfall.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1,2 s = quadro 36** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 10 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×1,33** para o golpe cair em 1,2 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_starfall`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
