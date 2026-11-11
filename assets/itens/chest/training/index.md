# Colete de treino (`training_vest`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Treino · **Slot:** Peito (pasta `chest/`) · **Vida extra:** +0
- **Descrição:** Colete de couro acolchoado.
- **No boneco:** encaixe automático no tronco de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/` (vazia) | — | ❌ falta (item não aparece no boneco) |
| Feminino | `female/` (vazia) | — | ❌ falta (item não aparece no boneco) |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Escudo — pasta `animation-skill-1/`

- `shield` · mira em você. Escudo que absorve dano por pouco tempo.
- Números: **Escudo 30** por 4 s · lançamento **0,2 s** · recarga **18 s** · mana **20**.
- Como funciona: Toque e sai, em você mesmo: dá um escudo que absorve 30 de dano por 4 s depois de 0,2 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: brilho na mão durante o lançamento. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/shield.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,2 s = quadro 6** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 18 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `buff`: dura 1,5 s (quadro 45), golpe em 0,57 s (quadro 17) → o jogo toca a **×2,85** para o golpe cair em 0,2 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_shield`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
