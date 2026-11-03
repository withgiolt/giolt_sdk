default:
    @just --list

test:
    gleam test --target javascript

test-bun:
    gleam test --target javascript --runtime bun

build-npm:
    gleam build --target javascript
    rm -rf dist
    mkdir -p dist/esgleam
    npx --yes esbuild@0.28.2 npm/bin.mjs --bundle --platform=node --format=esm --outfile=dist/giolt.mjs
    cp src/giolt/internal/esgleam/streaming_tar.mjs src/giolt/internal/esgleam/LICENSE src/giolt/internal/esgleam/NOTICE dist/esgleam/
    cp npm/package.json README.md LICENSE dist/
    cd dist && npm version "$(grep '^version' ../gleam.toml | cut -d'"' -f2)" --no-git-tag-version --allow-same-version

publish-hex:
    gleam build
    printf 'I am not using semantic versioning\n' | gleam publish --yes
