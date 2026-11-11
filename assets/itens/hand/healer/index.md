# Livro sagrado (`healer_tome`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Curandeiro · **Slot:** Arma (mão) (pasta `hand/`) · **Vida extra:** +0
- **Descrição:** Tomo branco com um sol dourado. Não causa dano: cura e protege os aliados.
- **No boneco:** preso à mão direita; pegada e jeito de segurar em `ItemModels` ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/hand-healer.tscn` | ×0,3, origem do modelo em (0; 0,08; 0) m | ✅ própria |
| Feminino | `female/hand-healer.tscn` | ×0,3, origem do modelo em (0; 0,08; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada.

### Ataque simples: Toque de luz — pasta `animation-attack/`

- `tome_attack` · mira aliado (ou você). Cura constante no aliado escolhido.
- Números: **Cura 8** · alcance 9 m · lançamento **1,2 s** · recarga **1,2 s** · sem mana.
- Como funciona: Toque no ⚔: fixa o **aliado mais perto** (até 10 m) e o personagem passa a curá-lo sozinho a cada 1,2 s (sem aliado por perto: só avisa "Nenhum aliado por perto" — não cura você). Segurar, arrastar até um aliado e soltar escolhe quem. Cada vez cura 8 depois de 1,2 s de lançamento (andar nesse tempo cancela); o aliado precisa estar a até 9 m.
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um aliado, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).

### Habilidade 1: Cura maior — pasta `animation-skill-1/`

- `greater_heal` · mira aliado (ou você). Cura forte no aliado (sem alvo: em você).
- Números: **Cura 35** · alcance 10 m · lançamento **1 s** · recarga **8 s** · mana **20**.
- Como funciona: Toque: no aliado em foco, ou em você se não houver. Arraste até um aliado e solte para escolher (ninguém na mira = você), até 10 m: cura 35 depois de 1 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um aliado, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/greater_heal.png`.

### Habilidade 2: Círculo de cura — pasta `animation-skill-2/`

- `healing_circle` · mira ao redor de você. Cura você e os aliados em volta.
- Números: **Cura 25** · raio 5 m · lançamento **0,8 s** · recarga **12 s** · mana **25**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,8 s de lançamento (andar nesse tempo cancela), todos os aliados (e você) em volta num raio de 5 m: cura 25.
- Ao segurar (prévia): círculo dourado translúcido de raio 5 m em volta do personagem.
- Os outros veem: brilho na mão durante o lançamento; **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/healing_circle.png`.

### Habilidade 3: Escudo sagrado — pasta `animation-skill-3/`

- `holy_shield` · mira aliado (ou você). Escudo no aliado (sem alvo: em você).
- Números: **Escudo 40** por 5 s · alcance 10 m · lançamento **0,3 s** · recarga **14 s** · mana **20**.
- Como funciona: Toque: no aliado em foco, ou em você se não houver. Arraste até um aliado e solte para escolher (ninguém na mira = você), até 10 m: dá um escudo que absorve 40 de dano por 5 s depois de 0,3 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um aliado, aparece o marcador de alvo embaixo dele.
- Os outros veem: brilho na mão durante o lançamento. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/holy_shield.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
