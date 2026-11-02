default:
    @just --list

test:
    gleam test --target javascript

publish-hex:
    gleam build
    printf 'I am not using semantic versioning\n' | gleam publish --yes
