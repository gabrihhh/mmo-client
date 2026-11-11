# Peitoral de placas (`knight_plate`)

> **Gerado** por `mmo-docs/tools/gerar_catalogo_itens.py` a partir do código (números do servidor,
> `mmo-server/src/items/catalog.ts`). Não editar acima de **Anotações**: mudou o item → rodar o gerador.
> Arquitetura desta pasta: mmo-docs [ART-08]. Catálogo completo: [ITEM-01].

- **Conjunto:** Cavaleiro · **Slot:** Peito (pasta `chest/`) · **Vida extra:** +70
- **Descrição:** Couraça de aço com tabardo azul.
- **No boneco:** encaixe automático no tronco de cada corpo ([ART-04]): a escala final no jogo depende do corpo.

## Malhas (uma por corpo)

| Corpo | Arquivo | Escala na cena | Situação |
|---|---|---|---|
| Masculino | `male/chest-knight.tscn` | ×1, origem do modelo em (0; 0; 0) m | ✅ própria |
| Feminino | `female/chest-knight.tscn` | ×1, origem do modelo em (0; 0; 0) m | ⚠ cópia idêntica da masculina — falta a malha feita para este corpo |

## Habilidades

Cada habilidade tem a pasta da sua animação própria (`male.glb` e `female.glb`, [ART-08]). Pasta vazia = usa a
animação genérica indicada. Os dois corpos usam os mesmos tempos. Animação em **30 fps**, personagem no lugar
(sem andar: quem move é o jogo). Parado, toca no corpo todo; andando, só tronco e braços (as pernas correm).

### Ataque simples — pasta `animation-attack/`

Este item não tem ataque simples (só a arma tem); pasta reservada.

### Habilidade 1: Muralha de aço — pasta `animation-skill-1/`

- `steel_wall` · mira em você. Escudo grande e duradouro.
- Números: **Escudo 60** por 6 s · lançamento **0,5 s** · recarga **22 s** · mana **25**.
- Como funciona: Toque e sai, em você mesmo: dá um escudo que absorve 60 de dano por 6 s depois de 0,5 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): nenhuma (não há o que mirar; soltar só lança).
- Os outros veem: só a animação. Animação: `buff` (Meshy; genérica, também em 14 outras).
- Desenho da carta: ✅ `assets/icons/abilities/steel_wall.png`.
- **Tempo da animação (Blender, 30 fps):**
  - **Momento do efeito** (golpe acerta / magia sai): **0,5 s = quadro 15** contando do início — é quando o servidor aplica o efeito (fim do lançamento).
  - Recarga 22 s (não repete em seguida): depois do efeito, uma volta curta ao repouso (~0,3–0,6 s) basta.
  - Hoje usa a genérica `buff`: dura 1,5 s (quadro 45), golpe em 0,57 s (quadro 17) → o jogo toca a **×1,14** para o golpe cair em 0,5 s.
  - Fazendo o golpe exatamente no quadro acima, ela toca na velocidade normal (×1). Se ficar em outro quadro, o jogo acelera ou desacelera (entre ×0,25 e ×4) desde que o golpe seja medido em `CharacterAnimator.HIT_TIMES` (`skill_steel_wall`).

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
