# giolt_sdk

[![Package Version](https://img.shields.io/hexpm/v/giolt_sdk)](https://hex.pm/packages/giolt_sdk)

## Run via Gleam

```sh
gleam add giolt_sdk
```

```sh
gleam run -m giolt
```

## Run via NPM

```sh
npx @giolt/sdk
```

## Config

```toml
# gleam.toml

[tools.giolt]
outdir = "./dist"
static_dir = "./public"
prebuild_command = "gleam run -m build"
entry_module = "app"
bundle_aliases = [
    "@gleam=./build/dev/javascript"
]
```

Documentation can be found at [docs.giolt.com](https://docs.giolt.com)
