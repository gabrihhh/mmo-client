# Elmo do cavaleiro (`knight_helm`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Cavaleiro · **Slot:** Cabeça (pasta `head/`) · **Vida extra:** +40
- **Descrição:** Elmo de aço com crista azul.
- **No boneco:** assenta na cabeça pelo `head_item_offset`/`head_item_scale` da cena do personagem ([ART-03]).

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/head-knight.tscn` | ×0,44, origem do modelo em (0; 0,21; 0) m | ✅ própria |
| Feminino | `female/head-knight.tscn` | ×0,44, origem do modelo em (0; 0,21; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Grito de proteção — pasta `animation-skill-1/`

- `rallying_cry` · mira ao redor de você. Escudo em você e nos aliados em volta.
- Números: **Escudo 25** por 5 s · raio 4 m · lançamento **0,3 s** · recarga **18 s** · mana **20**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,3 s de lançamento (andar nesse tempo cancela), todos os aliados (e você) em volta num raio de 4 m: dá um escudo que absorve 25 de dano por 5 s.
- Ao segurar (prévia): círculo dourado translúcido de raio 4 m em volta do personagem.
- Os outros veem: **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/rallying_cry.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,3 s = quadro 9** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 18 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `buff`: dura 1,5 s (quadro 45), golpe em 0,57 s (quadro 17) → o jogo toca a **×1,9** para o golpe cair em 0,3 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_rallying_cry`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
