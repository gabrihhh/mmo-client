# mmo-client — Cliente do jogo (Godot 4, GDScript)

MMO isométrico 3D low poly. **Plataformas-alvo: Android e iOS** (desktop só para desenvolvimento).
Repositórios irmãos em `../`: `mmo-server` (Node + ws), `mmo-docs` (documentação central).

## Documentação central (ler antes de decidir algo)

Toda decisão de design/arquitetura vive em `../mmo-docs`. Siga o protocolo de busca de lá:
leia `../mmo-docs/INDICE.md` e depois `../mmo-docs/tools/secao.sh <ID>`. Não abra os arquivos de `docs/` inteiros.
Seções-chave deste repo: [CLI-02] câmera, [CLI-03] estrutura do cliente, [CLI-04] jogador/controles,
[INFRA-04] protocolo de rede, [INFRA-09] modelo autoritativo, [INFRA-07] contas, [CLI-05] login, [VIS-04] plataformas mobile (retrato).

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
- Mudou `scripts/sim/movement.gd` → mesma conta e ordem em `mmo-server/src/sim/movement.ts` e [INFRA-09].
- **Servidor é a autoridade** ([INFRA-09]): o cliente manda intenção (`input`) e prevê; nunca decide posição/resultado.

### 4. Atualizador (o jogo chega por um .pck — [INFRA-08])
- **Nada de autoload** nem configuração nova no `project.godot` sem pensar: ele fica preso no APK.
  Serviços globais são criados pelo `GameBoot` (ex.: `Network.instance`).
- `scripts/boot/updater.gd` vai no APK: não pode usar classes do jogo. Mudou ele → APK novo e `LAUNCHER_VERSION` + 1.

### 5. Mobile primeiro
- Todo controle precisa funcionar por toque. Teclado/mouse são só atalhos de desenvolvimento.
- Renderer `mobile`; pensar em custo de draw calls, sombras e polígonos (low poly).

## Estrutura

```
scenes/            .tscn por domínio (boot/, ui/, world/, player/)
scripts/           .gd por domínio (boot/, network/, player/, camera/, ui/, input/, world/)
tools/             publish_update.sh (publica o .pck no servidor), build_apk.sh (gera o APK), placeholders/ ([ART-02])
assets/            modelos/materiais exportados do Blender (corpos, ícones, UI, placeholders)
assets/itens/      um item por pasta: <slot>/<nome>/{index.md, male/, female/, animation-*} ([ART-08])
```

## Comandos

```bash
godot --path . --headless --editor --quit         # importa e acusa erros de script
godot --path .                                    # roda o jogo (servidor precisa estar no ar)
godot --path . --headless --quit-after 300 -- --dev-user=Teste   # valida conexão sem clicar ([CLI-05])
godot --path . -- --profile=2 --dev-user=Teste2   # 2ª janela no mesmo PC, outra conta
godot --path . --headless --max-fps 60 -- --dev-user=Bot --bot-walk   # anda sozinho e mede correções ([INFRA-09])
godot --path . -- --profile=luta --dev-user=Lutador --bot-fight      # luta sozinho de cajado: animações, projéteis ([JOGO-08])
godot --path . -- --profile=espada --dev-user=Espada --bot-fight=espada   # idem de espada (anda até o boneco)
godot --headless --path . --script res://tools/placeholders/make_character.gd   # gera o personagem ([ART-03])
tools/publish_update.sh android                   # publica versão nova do jogo p/ celular ([INFRA-08])
tools/build_apk.sh --install                      # gera o APK e instala no aparelho do adb ([CLI-06])
python3 tools/blender/export_items.py chest-healer-female   # peça do workspace-blender → jogo ([ART-09])
python3 tools/blender/export_zone.py                         # spawn.blend → mapa da zona 1 + monstros ([ART-10])
```

Código e identificadores em inglês; comentários e docs em português.
