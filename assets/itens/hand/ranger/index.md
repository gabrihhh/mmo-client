# Besta de caça (`ranger_crossbow`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Atirador · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Besta leve de madeira escura. Tiros constantes de bem longe.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-ranger.tscn` | ×0,68, origem do modelo em (0; 0,1; 0) m | ✅ própria |
| Feminino | `female/hand-ranger.tscn` | ×0,68, origem do modelo em (0; 0,1; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Ataque — pasta `animation-attack/`

- `crossbow_attack` · mira direção (linha). Virote que voa reto e acerta o primeiro inimigo.
- Números: **Dano 5** · alcance 11 m · meia-largura 0,3 m · projétil 24 m/s (dá para desviar) · sai na hora · execução **0,6 s** · sem mana.
- Como funciona: Toque no ⚔: golpe na direção do **inimigo mais perto** (ou para a frente). Arrastar mostra o formato do golpe na direção do dedo e solta ao largar. Sem carregamento: o golpe sai na hora — um projétil a 24 m/s voa reto até 11 m e para no PRIMEIRO que tocar (inimigo) (tira 5 de vida). Depois, 0,6 s de execução em que outro golpe não sai. Dá para andar batendo.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 11 m de comprimento × 0,6 m de largura.
- Os outros veem: o personagem virado para a direção do golpe; projétil voando de verdade. Animação: `shoot_rifle` (Meshy; genérica, também em 2 outras).
- **Tempo da animação (Blender, 30 fps):**
  - **Sai na hora** (sem carregamento): o jogo toca a animação acelerada para o golpe cair a ~0,15 s do toque.
  - Tempo de execução **0,6 s = quadro 18**: a animação inteira deve caber nisso para emendar no próximo golpe (o jogador pode tocar de novo assim que acabar).

### Habilidade 1: Virote certeiro — pasta `animation-skill-1/`

- `piercing_bolt` · mira direção (linha). Virote muito rápido que acerta o primeiro no caminho.
- Números: **Dano 22** · alcance 16 m · meia-largura 0,4 m · projétil 26 m/s (dá para desviar) · lançamento **0,6 s** · recarga **5 s** · mana **15**.
- Como funciona: Arraste para apontar a linha (toque = na direção do alvo fixo ou para a frente) e solte; depois de 0,6 s de lançamento (andar nesse tempo cancela), um projétil a 26 m/s acerta o PRIMEIRO inimigo no caminho (até 16 m): tira 22 de vida.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 16 m de comprimento × 0,8 m de largura.
- Os outros veem: aviso no chão (faixa) até o efeito; projétil voando de verdade. Animação: `shoot_rifle` (Meshy; genérica, também em 2 outras).
- Desenho da carta: ✅ `assets/icons/abilities/piercing_bolt.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,6 s = quadro 18** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil de verdade sai no momento do efeito (26 m/s).
  - Recarga 5 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `shoot_rifle`: dura 0,27 s (quadro 8), golpe em 0,07 s (quadro 2) → o jogo toca a **×0,25** para o golpe cair em 0,6 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_piercing_bolt`).

### Habilidade 2: Chuva de virotes — pasta `animation-skill-2/`

- `bolt_rain` · mira área num ponto. Dispara para o alto e os virotes caem numa área.
- Números: **Dano 22** · alcance 13 m · raio 2,5 m · lançamento **1 s** · recarga **10 s** · mana **25**.
- Como funciona: Arraste para pôr o círculo no chão (até 13 m; toque = no alvo fixo ou à frente) e solte; depois de 1 s de lançamento (andar nesse tempo cancela), todos os inimigos dentro do raio de 2,5 m: tira 22 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m no ponto do dedo (até 13 m), com a linha até ele.
- Os outros veem: aviso no chão (círculo) até o efeito. Animação: `cast_up` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/bolt_rain.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1 s = quadro 30** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 10 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×1,6** para o golpe cair em 1 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_bolt_rain`).

### Habilidade 3: Tiro rápido — pasta `animation-skill-3/`

- `quick_shot` · mira no alvo. Tiro quase instantâneo no alvo.
- Números: **Dano 14** · alcance 12 m · lançamento **0,3 s** · recarga **6 s** · mana **10**.
- Como funciona: Com alvo fixo, um toque lança nele; sem alvo, arraste até um inimigo e solte. O alvo precisa estar a até 12 m no fim; tira 14 de vida depois de 0,3 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: projétil visual que sai da mão e chega junto com o dano. Animação: `shoot_rifle` (Meshy; genérica, também em 2 outras).
- Desenho da carta: ✅ `assets/icons/abilities/quick_shot.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,3 s = quadro 9** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - O projétil visual **sai da mão em 0,2 s = quadro 6** (voa 0,1 s até o alvo).
  - Recarga 6 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `shoot_rifle`: dura 0,27 s (quadro 8), golpe em 0,07 s (quadro 2) → o jogo toca a **×0,25** para o golpe cair em 0,3 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_quick_shot`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
