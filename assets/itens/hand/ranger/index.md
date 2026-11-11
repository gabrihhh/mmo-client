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
animação genérica indicada.

### Ataque simples: Ataque — pasta `animation-attack/`

- `crossbow_attack` · mira no alvo. Virote no alvo.
- Números: **Dano 10** · alcance 11 m · lançamento **1,2 s** · recarga **1,2 s** · sem mana.
- Como funciona: Toque no ⚔: fixa como alvo o **inimigo mais perto** (até 10 m) e o personagem passa a atacar sozinho a cada 1,2 s, até o alvo morrer ou você soltar (Desfocar). Segurar, arrastar até alguém e soltar escolhe o alvo. O personagem **não anda sozinho** até ele: começa a bater quando você para a até 11 m (+0,5 m de folga). Cada golpe tira 10 de vida depois de 1,2 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: projétil visual que sai da mão e chega junto com o dano. Animação: `attack_staff` (Meshy; genérica, também em 2 outras).

### Habilidade 1: Virote certeiro — pasta `animation-skill-1/`

- `piercing_bolt` · mira direção (linha). Virote muito rápido que acerta o primeiro no caminho.
- Números: **Dano 22** · alcance 16 m · meia-largura 0,4 m · projétil 26 m/s (dá para desviar) · lançamento **0,6 s** · recarga **5 s** · mana **15**.
- Como funciona: Arraste para apontar a linha (toque = na direção do alvo fixo ou para a frente) e solte; depois de 0,6 s de lançamento (andar nesse tempo cancela), um projétil a 26 m/s acerta o PRIMEIRO inimigo no caminho (até 16 m): tira 22 de vida.
- Ao segurar (prévia): faixa dourada translúcida saindo do personagem na direção do dedo: 16 m de comprimento × 0,8 m de largura.
- Os outros veem: aviso no chão (faixa) até o efeito; projétil voando de verdade. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/piercing_bolt.png`.

### Habilidade 2: Chuva de virotes — pasta `animation-skill-2/`

- `bolt_rain` · mira área num ponto. Dispara para o alto e os virotes caem numa área.
- Números: **Dano 22** · alcance 13 m · raio 2,5 m · lançamento **1 s** · recarga **10 s** · mana **25**.
- Como funciona: Arraste para pôr o círculo no chão (até 13 m; toque = no alvo fixo ou à frente) e solte; depois de 1 s de lançamento (andar nesse tempo cancela), todos os inimigos dentro do raio de 2,5 m: tira 22 de vida.
- Ao segurar (prévia): círculo dourado translúcido de raio 2,5 m no ponto do dedo (até 13 m), com a linha até ele.
- Os outros veem: aviso no chão (círculo) até o efeito. Animação: `cast_up` (Meshy; genérica, também em 5 outras).
- Desenho da carta: ✅ `assets/icons/abilities/bolt_rain.png`.

### Habilidade 3: Tiro rápido — pasta `animation-skill-3/`

- `quick_shot` · mira no alvo. Tiro quase instantâneo no alvo.
- Números: **Dano 14** · alcance 12 m · lançamento **0,3 s** · recarga **6 s** · mana **10**.
- Como funciona: Com alvo fixo, um toque lança nele; sem alvo, arraste até um inimigo e solte. O alvo precisa estar a até 12 m no fim; tira 14 de vida depois de 0,3 s de lançamento (andar nesse tempo cancela).
- Ao segurar (prévia): círculo dourado translúcido (1,5 m) que segue o dedo, com uma linha saindo do personagem; passando sobre um inimigo, aparece o marcador de alvo embaixo dele.
- Os outros veem: projétil visual que sai da mão e chega junto com o dano. Animação: `cast_forward` (Meshy; genérica, também em 7 outras).
- Desenho da carta: ✅ `assets/icons/abilities/quick_shot.png`.

## Anotações

(Livre: escreva aqui o que não vem do código — referências, ideias, pendências. O gerador preserva.)
