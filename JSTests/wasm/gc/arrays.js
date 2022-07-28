//@ runWebAssemblySuite("--useWebAssemblyTypedFunctionReferences=true", "--useWebAssemblyGC=true")

import * as assert from "../assert.js";
import { compile, instantiate } from "./wast-wrapper.js";

function module(bytes, valid = true) {
  let buffer = new ArrayBuffer(bytes.length);
  let view = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; ++i) {
    view[i] = bytes.charCodeAt(i);
  }
  return new WebAssembly.Module(buffer);
}

function testArrayDeclaration() {
  instantiate(`
    (module
      (type (array i32))
    )
  `);

  instantiate(`
    (module
      (type (array (mut i32)))
    )
  `);

  /*
   * invalid element type
   * (module
   *   (type (array <invalid>))
   * )
   */
  assert.throws(
    () => new WebAssembly.Instance(module("\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x84\x80\x80\x80\x00\x01\x5e\xff\x02")),
    WebAssembly.CompileError,
    "Module doesn't parse at byte 17: can't get array's element Type"
  )

  /*
   * invalid mut value 0x02
   * (module
   *   (type (array (<invalid> i32)))
   * )
   */
  assert.throws(
    () => new WebAssembly.Instance(module("\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x84\x80\x80\x80\x00\x01\x5e\x7f\x02")),
    WebAssembly.CompileError,
    "WebAssembly.Module doesn't parse at byte 18: invalid array mutability: 0x02"
  )

  instantiate(`
    (module
      (type (array i32))
      (func (result (ref null 0)) (ref.null 0))
    )
  `);

  instantiate(`
    (module
      (type (array i32))
      (func (result arrayref) (ref.null 0))
    )
  `);

  assert.throws(
    () => compile(`
      (module
        (type (array i32))
        (func (result funcref) (ref.null 0))
      )
    `),
    WebAssembly.CompileError,
    "control flow returns with unexpected type. RefNull is not a RefNull, in function at index 0"
  );
}

testArrayDeclaration();
