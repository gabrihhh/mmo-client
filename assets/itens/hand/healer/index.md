# Livro sagrado (`healer_tome`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Curandeiro · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Tomo branco com um sol dourado. Não causa dano: cura e protege os aliados.
- **No boneco:** flutua na frente do personagem (mão vazia), fechado; abre durante os lançamentos (blend shape do Blender) — posições em `ItemModels._FLOATING` ([ART-09]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-healer.glb` | ×1 (o .glb direto, no espaço do personagem) | ✅ **do Blender** (flutua na frente do personagem; mesma malha nos dois corpos) |
| Feminino | `female/hand-healer.glb` | ×1 (o .glb direto, no espaço do personagem) | ✅ **do Blender** (flutua na frente do personagem; mesma malha nos dois corpos) |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples: Toque de luz — pasta `animation-attack/`

- `tome_attack` · mira direção (linha). Raio de luz que voa reto: cura o primeiro aliado ou fere o primeiro inimigo.
- Números: **Dano 2** · **Cura 4** · alcance 9 m · meia-largura 0,35 m · projétil 16 m/s (dá para desviar) · sai na hora · execução **0,6 s** · sem mana.
- Como funciona: Toque no ⚔: golpe na direção do **inimigo mais perto** (ou para a frente). Arrastar mostra o formato do golpe na direção do dedo e solta ao largar. Sem carregamento: o golpe sai na hora — um projétil a 16 m/s voa reto até 9 m e para no PRIMEIRO que tocar: aliado é curado, inimigo leva o dano (tira 2 de vida, cura 4). Depois, 0,6 s de execução em que outro golpe não sai. Dá para andar batendo.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 9 m de comprimento × 0,7 m de largura.
- Os outros veem: o personagem virado para a direção do golpe; projétil voando de verdade. Animação: `cast_heal` (Meshy; genérica, também em 2 outras).
- **Tempo da animação (Blender, 30 fps):**
  - **Sai na hora** (sem carregamento): o jogo toca a animação acelerada para o golpe cair a ~0,15 s do toque.
  - Tempo de execução **0,6 s = quadro 18**: a animação inteira deve caber nisso para emendar no próximo golpe (o jogador pode tocar de novo assim que acabar).

### Habilidade 1: Cura maior — pasta `animation-skill-1/`

- `greater_heal` · mira aliado (ou você). Cura forte no aliado (sem alvo: em você).
- Números: **Cura 35** · alcance 10 m · lançamento **1 s** · recarga **8 s** · mana **20**.
- Como funciona: Toque: no aliado em foco, ou em você se não houver. Arraste até um aliado e solte para escolher (ninguém na mira = você), até 10 m: cura 35 depois de 1 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um aliado, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento. Animação: `cast_heal` (Meshy; genérica, também em 2 outras).
- Desenho da carta: ✅ `assets/icons/abilities/greater_heal.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **1 s = quadro 30** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 8 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_heal`: dura 1,6 s (quadro 48), golpe em 0,65 s (quadro 20) → o jogo toca a **×0,65** para o golpe cair em 1 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_greater_heal`).

### Habilidade 2: Círculo de cura — pasta `animation-skill-2/`

- `healing_circle` · mira ao redor de você. Cura você e os aliados em volta.
- Números: **Cura 25** · raio 5 m · lançamento **0,8 s** · recarga **12 s** · mana **25**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,8 s de lançamento (andar nesse tempo cancela), todos os aliados (e você) em volta num raio de 5 m: cura 25.
- Ao segurar (prévia): círculo dourado translúcido de raio 5 m em volta do personagem.
- Os outros veem: brilho na mão durante o lançamento; **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `cast_up` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/healing_circle.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,8 s = quadro 24** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 12 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×2** para o golpe cair em 0,8 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_healing_circle`).

### Habilidade 3: Escudo sagrado — pasta `animation-skill-3/`

- `holy_shield` · mira aliado (ou você). Escudo no aliado (sem alvo: em você).
- Números: **Escudo 40** por 5 s · alcance 10 m · lançamento **0,3 s** · recarga **14 s** · mana **20**.
- Como funciona: Toque: no aliado em foco, ou em você se não houver. Arraste até um aliado e solte para escolher (ninguém na mira = você), até 10 m: dá um escudo que absorve 40 de dano por 5 s depois de 0,3 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um aliado, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento. Animação: `cast_heal` (Meshy; genérica, também em 2 outras).
- Desenho da carta: ✅ `assets/icons/abilities/holy_shield.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,3 s = quadro 9** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 14 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_heal`: dura 1,6 s (quadro 48), golpe em 0,65 s (quadro 20) → o jogo toca a **×2,17** para o golpe cair em 0,3 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_holy_shield`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
