# giolt_sdk

[![Package Version](https://img.shields.io/hexpm/v/giolt_sdk)](https://hex.pm/packages/giolt_sdk)

The Giolt SDK for building, developing and deploying Gleam apps on the edge.

`giolt_sdk` is a library. You write plain Gleam scripts that call into it, and
you own your own build.

Version 3.0.0 is the last major release. The package is being replaced by
`giolt`, a CLI run with `gleam run -m giolt` and configured in `gleam.toml`
(see [withgiolt/issues#1](https://github.com/withgiolt/issues/issues/1)).

## Upgrading to 3.0.0

The worker entry now calls `handle` instead of `handler`. Rename the export in
your entry module. A module that only exports `handler` gets a 500 that says
so.

## Install

```sh
gleam add giolt_sdk
```

## Documentation

Full docs, including a get-started guide and the complete SDK reference, live
at [docs.giolt.com/sdk](https://docs.giolt.com/sdk).

## Issues

Found a bug or have a feature request? File it at
[github.com/withgiolt/issues](https://github.com/withgiolt/issues).
