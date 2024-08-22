// c.js

import "./d.js";
import "./f.js";

var global = (Function("return this"))();
global.cEvaluated = true;

export let value = 2;
