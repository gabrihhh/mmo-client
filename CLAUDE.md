# mmo-client — Cliente do jogo (Godot 4, GDScript)

MMO isométrico 3D low poly. **Plataformas-alvo: Android e iOS** (desktop só para desenvolvimento).
Repositórios irmãos em `../`: `mmo-server` (Node + ws), `mmo-docs` (documentação central).

## Documentação central (ler antes de decidir algo)

Toda decisão de design/arquitetura vive em `../mmo-docs`. Siga o protocolo de busca de lá:
leia `../mmo-docs/INDICE.md` e depois `../mmo-docs/tools/secao.sh <ID>`. Não abra os arquivos de `docs/` inteiros.
Seções-chave deste repo: [CLI-02] câmera, [CLI-03] estrutura do cliente, [CLI-04] jogador/controles,
[INFRA-04] protocolo de rede, [VIS-04] plataformas mobile.

## Regras OBRIGATÓRIAS

### 1. Tipagem forte (GDScript estático)
- `project.godot` trata declaração sem tipo como **erro** (`untyped_declaration=2`). Não afrouxar.
- Toda variável, parâmetro, retorno, constante e `@export` com tipo explícito (`var x: float = 0.0`, `-> void`).
- Coleções tipadas: `Array[T]`, `Dictionary[K, V]`.
- Referências a nós com tipo: `@onready var _camera: IsometricCamera = $Camera`.
- Scripts reutilizáveis têm `class_name`. Valor vindo da rede (JSON) é `Variant`: checar com `is` e atribuir a variável tipada (ver `Protocol.read_*`, [PAD-02]).

### 2. Documentação no código
- Todo script começa com `##` descrevendo responsabilidade (doc comment do Godot, aparece no editor).
- Todo `@export`, sinal, método público e constante tem `##` explicando o quê / por quê, com unidades (m, rad, Hz, px).
- Privados (`_nome`) documentados quando a intenção não for óbvia.
- Contratos com o servidor levam `ATENÇÃO:` apontando o arquivo espelho no `mmo-server`.

### 3. Toda alteração atualiza a documentação
- Mudou comportamento → atualize os `##` **e** a seção correspondente no `mmo-docs`.
- Não existe seção → crie uma (seguindo `../mmo-docs/CLAUDE.md`) e registre no `INDICE.md`.
- Removeu algo → remova/atualize a doc no código e no `mmo-docs` no mesmo passo. Documentação desatualizada é bug.
- Mudou `scripts/network/protocol.gd` ou mensagens em `network.gd` → espelhe em `mmo-server/src/net/protocol.ts` e atualize [INFRA-04].

### 4. Mobile primeiro
- Todo controle precisa funcionar por toque. Teclado/mouse são só atalhos de desenvolvimento.
- Renderer `mobile`; pensar em custo de draw calls, sombras e polígonos (low poly).

## Estrutura

```
scenes/            .tscn por domínio (world/, player/)
scripts/           .gd por domínio (network/, player/, camera/, ui/, input/, world/)
assets/            modelos/materiais exportados do Blender
```

## Comandos

```bash
godot --path . --headless --editor --quit         # importa e acusa erros de script
godot --path .                                    # roda o jogo (servidor precisa estar no ar)
```

Código e identificadores em inglês; comentários e docs em português.
