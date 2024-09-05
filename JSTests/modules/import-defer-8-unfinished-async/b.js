// b.js

import * as assert from "../resources/assert.js";
import defer * as ns from "./c.js";

export { ns };

var global = (Function("return this"))();
assert.shouldBe(global.state, "d - finish");
global.state = "b";
