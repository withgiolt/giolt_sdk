# giolt_sdk

[![Package Version](https://img.shields.io/hexpm/v/giolt_sdk)](https://hex.pm/packages/giolt_sdk)

## Install

```sh
gleam add giolt_sdk
```

## Run

```sh
gleam run -m giolt
```

## Config

```toml
# gleam.toml

[tools.giolt]
outdir = "./dist",
static_dir = "./public",
entry_module = "app",
bundle_aliases = [
    "@gleam=./build/dev/javascript"
],
```

Documentation can be found at [docs.giolt.com](https://docs.giolt.com)
