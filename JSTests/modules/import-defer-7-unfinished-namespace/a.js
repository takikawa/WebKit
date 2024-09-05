// a.js

import * as assert from "../resources/assert.js";
import defer * as ns from "./b.js";

export let a_start;

var global = (Function("return this"))();
assert.shouldBe(global.state, undefined);
global.state = "a - start";

try {
  ns.b_start;
  assert.shouldBe(global.state, "b - finish");
  global.state = "ns.b_start ok";
} catch (exn) {
  throw new Error(`ns.b_start tdz: ` + exn.message);
}

try {
  ns.b_finish;
  assert.shouldBe(global.state, "ns.b_start ok");
  global.state = "ns.b_finish ok";
} catch (exn) {
  throw new Error(`ns.b_finish tdz: ` + exn.message);
}

assert.shouldBe(global.state, "ns.b_finish ok");
global.state = "a - finish";

export let a_finish;
