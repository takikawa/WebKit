//@ runWebAssemblySuite("--useWebAssemblyTypedFunctionReferences=true")
import * as assert from '../assert.js'
import Builder from '../Builder.js'

// Test (ref $t) types in signatures.
{
    const b = new Builder();
    b.Type()
     .Func(["i32"], "i32")
     .Func([], { ref: 0, nullable: false })
     .End()
     .Import().End()
     .Function().End()
     .Export()
     .Function("f")
     .End()
     .Code()
     .Function("f", 0)
     .I32Const(1)
     .Return()
     .End()
     .Function("g", 1)
     .RefFunc(0)
     .Return()
     .End()
     .End()

    const m = new WebAssembly.Module(b.WebAssembly().get());
}

// Test extern/func refs with non-default nullability.
{
    const b1 = new Builder();
    b1.Type()
     .Func(["externref"], { nullable: true, ref: "externref" })
     .End()
     .Import().End()
     .Function().End()
     .Export()
     .Function("f")
     .End()
     .Code()
     .Function("f", 0)
     .GetLocal(0)
     .Return()
     .End()
     .End()

    new WebAssembly.Module(b1.WebAssembly().get());

    const b2 = new Builder();
    b2.Type()
     .Func(["externref"], { nullable: false, ref: "externref" })
     .End()
     .Import().End()
     .Function().End()
     .Export()
     .Function("f")
     .End()
     .Code()
     .Function("f", 0)
     .GetLocal(0)
     .Return()
     .End()
     .End()

    assert.throws(() => new WebAssembly.Module(b2.WebAssembly().get()), WebAssembly.CompileError, "branch's stack type is not a block's type branch target type");

    const b3 = new Builder();
    b3.Type()
     .Func([], { nullable: false, ref: "funcref" })
     .End()
     .Import().End()
     .Function().End()
     .Export()
     .Function("f")
     .End()
     .Code()
     .Function("f", 0)
     .RefFunc(0)
     .Return()
     .End()
     .End()

    new WebAssembly.Module(b3.WebAssembly().get());

    const b4 = new Builder();
    b4.Type()
     .Func([{ nullable: true, ref: "funcref" }], { nullable: false, ref: "funcref" })
     .End()
     .Import().End()
     .Function().End()
     .Export()
     .Function("f")
     .End()
     .Code()
     .Function("f", 0)
     .GetLocal(0)
     .Return()
     .End()
     .End()

    assert.throws(() => new WebAssembly.Module(b4.WebAssembly().get()), WebAssembly.CompileError, "branch's stack type is not a block's type branch target type");
}
