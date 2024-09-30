import { shouldBe } from "./resources/assert.js"

var global = (Function("return this"))();

shouldBe(global.count, undefined);
global.count = 1;

let ns = await import.defer("./import-defer-dynamic/b.js");

shouldBe(global.count, 1);
