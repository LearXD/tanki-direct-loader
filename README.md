# SWF Runtime Bootstrap

Loader AIR/ActionScript para iniciar o client com um bootstrap proprio, sem passar pela tela do `StandaloneLoader` e do `Prelauncher`.

Fluxo atual:

1. Le argumentos do `adl`.
2. Monta os mesmos parametros que o `Prelauncher` passaria para o loader do jogo.
3. Carrega `GameLoader.swf` local, escrito para este projeto, com `LoaderContext.parameters`.
4. O `GameLoader.swf` carrega `config.xml` apenas por compatibilidade, ignora status de manutencao, carrega `hardware.swf` ou `software.swf`, e depois `library.swf`.
5. O `GameLoader.swf` instancia `Game` e chama `Game.SUPER(stage, launcher, loaderInfo)`.

## Requisitos

- Harman/Adobe AIR SDK com `mxmlc` e `adl` no `PATH`.
- `library.swf`, `hardware.swf` e `software.swf` locais ou remotos.

## Build

```bash
mxmlc -source-path src -output bin/DirectLoader.swf -swf-version 23 -default-background-color 0x000000 src/DirectLoaderBootstrap.as

mxmlc -source-path src -output bin/GameLoader.swf -swf-version 23 -default-background-color 0x000000 src/GameLoader.as
```

`DirectGameRuntime.swf` ainda existe no projeto como runtime experimental direto para `library.swf`, mas nao e usado no fluxo padrao.

## Uso Remoto

```bash
adl ./src/DirectLoader-app.xml ./bin -- --resources "http://146.59.110.103" --swf "http://146.59.110.103/library.swf" --ip "146.59.110.146" --port "25565" --lang "pt_BR"
```

## Uso Local

Coloque os SWFs em `bin` depois do build:

```text
bin/DirectLoader.swf
bin/GameLoader.swf
bin/library.swf
bin/hardware.swf
bin/software.swf
```

Execute:

```bash
adl ./src/DirectLoader-app.xml ./bin -- --resources "." --swf "library.swf" --ip "146.59.110.146" --port "25565" --lang "pt_BR"
```

## Argumentos

- `--resources`: base de recursos do client.
- `--loader`: caminho ou URL do `GameLoader.swf` ou `Loader.swf`. Se omitido, usa `GameLoader.swf`.
- `--swf`: caminho ou URL do `library.swf`. Se omitido, usa `resources/library.swf`.
- `--config`: caminho ou URL do `config.xml`. Opcional; se omitido, usa `resources/config.xml` apenas para manter compatibilidade com o fluxo do client.
- `--ip`: endereco do servidor de jogo.
- `--port`: porta do servidor de jogo.
- `--lang`: idioma (`ru`, `en`, `pt_BR`, etc.).

Alias mantido por compatibilidade:

- `--library` equivale a `--swf`.
