# mmo-client

Cliente Godot do MMO (Android/iOS). Documentação completa em `../mmo-docs` (comece pelo `INDICE.md`).

## Primeira vez

1. Instale o **Godot 4.4+** (recomendado 4.7.x, versão padrão, não a .NET).
2. Suba o servidor (`../mmo-server`: `npm start`).
3. Abra o projeto no Godot e aperte F5. Não há addons para instalar.

Para testar o multiplayer no mesmo PC: **Debug > Customize Run Instances...** → 2 instâncias.

## Controles

- Celular: joystick virtual no canto inferior esquerdo.
- Desktop (dev): WASD/setas, ou arraste o joystick com o mouse.

## Testar no celular

Em **Project Settings > mmo/network/server_url** troque `localhost` pelo IP do PC na rede local
(ex.: `ws://192.168.0.10:2567`). Android: habilite a permissão *Internet* no preset de exportação.
