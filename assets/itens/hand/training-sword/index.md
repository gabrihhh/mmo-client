# Espada de treino (`training_sword`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Treino · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Espada curva de duas mãos, boa para aprender a lutar de perto.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-training-sword.tscn` | ×0,527, origem do modelo em (0; 0,36; 0) m | ✅ própria |
| Feminino | `female/hand-training-sword.tscn` | ×0,527, origem do modelo em (0; 0,36; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples: Ataque — pasta `animation-attack/`

- `sword_attack` · mira no alvo. Golpe de espada no alvo.
- Números: **Dano 10** · alcance 2,5 m · lançamento **1 s** · recarga **1 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 1 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 2,5 m (+0,5 m de folga). Cada golpe tira 10 de vida depois de 1 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: clarão do golpe à frente (1,8 m) no momento do efeito. Animação: `attack_sword` (Meshy; genérica, também em 1 outra).

### Habilidade 1: Golpe forte — pasta `animation-skill-1/`

- `heavy_strike` · mira ao redor de você. Pancada no chão que acerta todos em volta.
- Números: **Dano 25** · raio 2,5 m · lançamento **0,5 s** · recarga **6 s** · mana **15**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,5 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 2,5 m: tira 25 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 2,5 m no momento do efeito. Animação: `heavy_strike` (Meshy; genérica, também em 3 outras).
- Desenho da carta: ✅ `assets/icons/abilities/heavy_strike.png`.

### Habilidade 2: Investida — pasta `animation-skill-2/`

- `dash` · mira direção (linha). Avança rápido na direção escolhida.
- Números: **Avança 6 m** em 0,3 s · alcance 6 m · meia-largura 1 m · lançamento **instantâneo** · recarga **8 s** · mana **10**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 6 m na direção, percorrendo o caminho em 0,3 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 6 m de comprimento × 2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/dash.png`.

### Habilidade 3: Giro — pasta `animation-skill-3/`

- `spin` · mira ao redor de você. Gira a espada e corta todos ao redor.
- Números: **Dano 15** · raio 3 m · lançamento **0,4 s** · recarga **10 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,4 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 3 m: tira 15 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 3 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 3 m no momento do efeito. Animação: `spin` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/spin.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
