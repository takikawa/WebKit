// a.js

import * as assert from "../resources/assert.js";
import "./b.js";

var global = (Function("return this"))();
assert.shouldBe(global.state, "b");
global.state = "a";
