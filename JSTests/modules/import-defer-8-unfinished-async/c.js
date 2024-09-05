// c.js

import "./d.js";

throw new Error(`deferred module should never be executed`);

export function c_fn() {}
export let c_tdz = 1;
