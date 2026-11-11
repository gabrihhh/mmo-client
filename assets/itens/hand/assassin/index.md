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
animação genérica indicada.

### Ataque simples: Ataque — pasta `animation-attack/`

- `dagger_attack` · mira no alvo. Golpe rápido de adaga no alvo.
- Números: **Dano 8** · alcance 2,2 m · lançamento **0,7 s** · recarga **0,7 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 0,7 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 2,2 m (+0,5 m de folga). Cada golpe tira 8 de vida depois de 0,7 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: clarão do golpe à frente (1,5 m) no momento do efeito. Animação: `attack_sword` (Meshy; genérica, também em 1 outra).

### Habilidade 1: Salto sombrio — pasta `animation-skill-1/`

- `shadow_leap` · mira direção (linha). Salta até o inimigo num instante.
- Números: **Avança 9 m** em 0,2 s · alcance 9 m · meia-largura 0,6 m · lançamento **instantâneo** · recarga **14 s** · mana **10**.
- Como funciona: Arraste para escolher a direção e solte (toque = para a frente/para o alvo): leva você 9 m na direção, percorrendo o caminho em 0,2 s. Começa na hora.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 9 m de comprimento × 1,2 m de largura.
- Os outros veem: só a animação. Animação: `dash` (Meshy; genérica, também em 4 outras).
- Desenho da carta: ✅ `assets/icons/abilities/shadow_leap.png`.

### Habilidade 2: Apunhalar — pasta `animation-skill-2/`

- `backstab` · mira no alvo. Golpe muito forte no alvo, de perto.
- Números: **Dano 50** · alcance 2,5 m · lançamento **0,2 s** · recarga **14 s** · mana **15**.
- Como funciona: Com alvo fixo, um toque lança nele; sem alvo, arraste até um inimigo e solte. O alvo precisa estar a até 2,5 m no fim; tira 50 de vida depois de 0,2 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: clarão do golpe à frente (1,8 m) no momento do efeito. Animação: `heavy_strike` (Meshy; genérica, também em 3 outras).
- Desenho da carta: ✅ `assets/icons/abilities/backstab.png`.

### Habilidade 3: Dança das lâminas — pasta `animation-skill-3/`

- `blade_flurry` · mira ao redor de você. Rodopia com as adagas e corta todos em volta.
- Números: **Dano 40** · raio 2,5 m · lançamento **0,3 s** · recarga **16 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,3 s de lançamento (andar nesse tempo cancela), todos os inimigos em volta num raio de 2,5 m: tira 40 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"); clarão do golpe em anel de 2,5 m no momento do efeito. Animação: `spin` (Meshy; genérica, também em 1 outra).
- Desenho da carta: ✅ `assets/icons/abilities/blade_flurry.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
