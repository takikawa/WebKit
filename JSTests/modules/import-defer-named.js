import { shouldBe } from "./resources/assert.js"

await import('./import-defer-named/named.js')
    .then($vm.abort, function (error) {
        shouldBe(String(error), `SyntaxError: Unexpected token '{'. Expected 'from' before imported module name.`);
    }).catch($vm.abort);
