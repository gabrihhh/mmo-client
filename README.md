# mmo-client

Cliente Godot do MMO (Android/iOS). Documentação completa em `../mmo-docs` (comece pelo `INDICE.md`).

## Primeira vez

Pasta `comandos/`: cada comando tem versão Linux (`.sh`) e Windows (`.bat`) — mmo-docs [PAD-05].

| | Linux | Windows (clique duplo) |
|---|---|---|
| Instalar (Godot 4.7.2 + importar) | `comandos/setup-linux.sh` | `comandos\setup-windows.bat` |
| Abrir o jogo | `comandos/run-game/linux.sh` | `comandos\run-game\windows.bat` |
| Abrir o jogo já logado como `Ana` | `comandos/run-game/linux.sh Ana` | `comandos\run-game\windows.bat Ana` (no terminal) |
| Abrir o editor | `comandos/open-editor/linux.sh` | `comandos\open-editor\windows.bat` |

No Windows é só dar dois cliques no `.bat` (o setup pede permissão de administrador; o jogo e o editor não).

O servidor precisa estar no ar (`../mmo-server/comandos/start-server/`). Cada nome abre uma janela com perfil
próprio, então `run-game Ana` e `run-game Bia` ao mesmo tempo testam o multiplayer no mesmo PC.

Na mão: instale o **Godot 4.7.x** (versão padrão, não a .NET), suba o servidor, abra o projeto no Godot e aperte F5.

O jogo abre na tela de login: crie uma conta (username, e-mail e senha) ou entre. O aparelho lembra a
sessão; **Sair** no canto da tela desloga.

Para testar o multiplayer no mesmo PC: **Debug > Customize Run Instances...** → 2 instâncias, e em cada uma
coloque um perfil diferente em *Launch Arguments* (ex.: `-- --profile=1 --dev-user=Ana` e
`-- --profile=2 --dev-user=Bia`); sem isso as duas janelas usam a mesma sessão e uma derruba a outra.

## Controles

- Celular: joystick virtual no canto inferior esquerdo.
- Desktop (dev): WASD/setas, ou arraste o joystick com o mouse.

## Testar no celular

Em **Project Settings > mmo/network/server_url** troque `localhost` pelo IP do PC na rede local
(ex.: `ws://192.168.0.10:2567`). Android: habilite a permissão *Internet* no preset de exportação.

## Publicar uma atualização

O APK só traz o atualizador; o jogo é baixado do servidor (mmo-docs [INFRA-08]).
Com o servidor rodando: `tools/publish_update.sh android` (celular) ou `tools/publish_update.sh desktop`.
Quem abrir o app depois disso recebe a versão nova.

## Gerar o APK

Requisitos e configuração: mmo-docs [CLI-06]. Antes, troque `mmo/network/server_url.android` no
`project.godot` pelo IP do PC que roda o servidor. Depois: `tools/build_apk.sh --install` (com o celular no adb)
ou mande o `build/mmo.apk` para quem vai instalar. PC e celular precisam estar na mesma rede Wi-Fi.
