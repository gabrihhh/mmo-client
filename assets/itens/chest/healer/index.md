# Manto da luz (`healer_robe`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Curandeiro · **Slot:** Peito (pasta `chest/`) · **Vida extra:** +0
- **Descrição:** Manto branco com faixa verde.
- **No boneco:** encaixe automático no tronco de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/chest-healer.tscn` | ×1, origem do modelo em (0; 0; 0) m | ✅ própria |
| Feminino | `female/chest-healer.tscn` | ×1, origem do modelo em (0; 0; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Égide — pasta `animation-skill-1/`

- `aegis` · mira ao redor de você. Escudo em você e nos aliados em volta.
- Números: **Escudo 25** por 4 s · raio 5 m · lançamento **0,4 s** · recarga **20 s** · mana **25**.
- Como funciona: Toque e sai (não precisa mirar): depois de 0,4 s de lançamento (andar nesse tempo cancela), todos os aliados (e você) em volta num raio de 5 m: dá um escudo que absorve 25 de dano por 4 s.
- Ao segurar (prévia): círculo dourado translúcido de raio 5 m em volta do personagem.
- Os outros veem: brilho na mão durante o lançamento; **sem aviso no chão** (o servidor não manda o ponto do "ao redor"). Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/aegis.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,4 s = quadro 12** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 20 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `cast_up`: dura 2,1 s (quadro 63), golpe em 1,6 s (quadro 48) → o jogo toca a **×4** para o golpe cair em 0,4 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_aegis`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
