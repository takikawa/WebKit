import { shouldBe } from "./resources/assert.js"

Promise.all([
    import('./import-defer/basic.js'),
    import('./import-defer/named.js')
        .then($vm.abort, function (error) {
            shouldBe(String(error), `SyntaxError: Unexpected identifier 'foo'. Expected 'as' before imported binding name.`);
        }).catch($vm.abort),
]).catch($vm.abort);
