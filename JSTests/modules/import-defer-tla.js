import { shouldBe } from "./resources/assert.js"

var global = (Function("return this"))();

import "./import-defer-tla/b.js";
import defer * as c from "./import-defer-tla/c.js";

shouldBe(global.bEvaluated, true);
shouldBe(global.cEvaluated, undefined);
shouldBe(global.dEvaluated, true);
shouldBe(global.eEvaluated, true);
shouldBe(global.fEvaluated, undefined);

shouldBe(c.value, 2);

shouldBe(global.bEvaluated, true);
shouldBe(global.cEvaluated, true);
shouldBe(global.dEvaluated, true);
shouldBe(global.eEvaluated, true);
shouldBe(global.fEvaluated, true);
