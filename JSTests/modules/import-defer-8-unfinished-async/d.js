// d.js

import * as assert from "../resources/assert.js";
import { ns } from "./b.js";

var global = (Function("return this"))();
assert.shouldBe(global.state, undefined);
global.state = "ns.c_fn: " + typeof ns.c_fn;

try {
  ns.c_tdz;
} catch (exn) {
  assert.shouldBe(global.state, "ns.c_fn: function");
  global.state = "ns.c_tdz: tdz";
}

assert.shouldBe(global.state, "ns.c_tdz: tdz");
global.state = "d - start";

await 0;

assert.shouldBe(global.state, "d - start");
global.state = "d - finish";
