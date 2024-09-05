// b.js

import * as assert from "../resources/assert.js";
import defer * as ns from "./a.js";

export let b_start;

var global = (Function("return this"))();
assert.shouldBe(global.state, "a - start");
global.state = "b - start";

try {
  ns.a_start;
  assert.shouldBe(global.state, "b - start");
  global.state = "ns.a_start ok";
} catch (exn) {
  throw new Error(`ns.a_start tdz: ` + exn.message);
}

try {
  ns.a_finish;
  throw new Error(`ns.b_finish ok: should be unreachable`);
} catch (exn) {
  assert.shouldBe(global.state, "ns.a_start ok");
  global.state = "ns.a_finish tdz";
}

assert.shouldBe(global.state, "ns.a_finish tdz");
global.state = "b - finish";

export let b_finish;
