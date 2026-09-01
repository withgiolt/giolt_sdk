default:
    @just --list

publish-npm:
    gleam build --target javascript
    deno bundle --minify ./priv/cli_entry.js -o ./bin/index.mjs
    npm publish --access public

publish-hex:
    gleam build
    gleam publish --yes
