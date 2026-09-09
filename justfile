default:
    @just --list

test:
    gleam test --target javascript

publish-hex:
    gleam build
    gleam publish --yes
