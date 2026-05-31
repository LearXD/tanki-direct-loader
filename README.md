# Tanki Direct Loader

Loader AIR/ActionScript para iniciar o `library.swf` diretamente, sem passar pelo `StandaloneLoader` e pelo `Prelauncher` originais.

Ele faz o minimo necessario para manter compatibilidade com o client:

1. Le argumentos do `adl`.
2. Injeta os parametros no runtime via `LoaderContext.parameters`.
3. Carrega `hardware.swf` ou `software.swf`.
4. Carrega o `library.swf`.
5. Instancia a classe `Game` e chama `Game.SUPER(stage, launcher, loaderInfo)`.

## Requisitos

- Harman/Adobe AIR SDK com `mxmlc` e `adl` no `PATH`.
- Arquivos runtime do jogo (`library.swf`, `hardware.swf`, `software.swf`) locais ou remotos.

## Build

```bash
mxmlc -source-path src -output bin/DirectGameRuntime.swf -swf-version 23 -default-background-color 0x000000 src/DirectGameLoader.as

mxmlc -source-path src -output bin/DirectLoader.swf -swf-version 23 -default-background-color 0x000000 src/DirectLoaderBootstrap.as
```

## Uso Remoto

```bash
adl ./src/DirectLoader-app.xml ./bin -- --resources "http://146.59.110.103" --library "http://146.59.110.103/library.swf" --ip "146.59.110.146" --port "25565" --lang "pt_BR" --engine auto
```

## Uso Local

Coloque os SWFs em `bin` depois do build:

```text
bin/DirectLoader.swf
bin/DirectGameRuntime.swf
bin/library.swf
bin/hardware.swf
bin/software.swf
```

Execute:

```bash
adl ./src/DirectLoader-app.xml ./bin -- --resources "." --library "library.swf" --hardware "hardware.swf" --software "software.swf" --ip "146.59.110.146" --port "25565" --lang "pt_BR" --engine auto
```

## Argumentos

- `--resources`: base de recursos do client. Ainda e usado pelo jogo para arquivos como `localized.data`.
- `--library`: caminho ou URL do `library.swf`.
- `--hardware`: caminho ou URL do `hardware.swf`.
- `--software`: caminho ou URL do `software.swf`.
- `--ip`: endereco do servidor de jogo.
- `--port`: porta do servidor de jogo.
- `--lang`: idioma (`ru`, `en`, `pt_BR`, etc.).
- `--engine`: `auto`, `hardware` ou `software`.

Aliases mantidos por compatibilidade:

- `--swf` equivale a `--library`.
- `--hardware-swf` equivale a `--hardware`.
- `--software-swf` equivale a `--software`.

Se `--library`, `--hardware` ou `--software` nao forem definidos, o loader usa `resources/library.swf`, `resources/hardware.swf` e `resources/software.swf`.
