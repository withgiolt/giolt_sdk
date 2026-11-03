default:
    @just --list

test:
    gleam test --target javascript

test-bun:
    gleam test --target javascript --runtime bun

publish-hex:
    gleam build
    printf 'I am not using semantic versioning\n' | gleam publish --yes
