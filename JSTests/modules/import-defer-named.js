import { shouldBe } from "./resources/assert.js"

await import('./import-defer/named.js')
    .then($vm.abort, function (error) {
        shouldBe(String(error), `SyntaxError: Unexpected token '{'. Cannot parse the namespace import.`);
    }).catch($vm.abort);
