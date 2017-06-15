# llvm-ss-2017
LLVM Summer School 2017

# Environment

Use this script: https://goo.gl/cieeWh

# Static Analysis

For static analysis, see: https://github.com/Xazax-hun/LLVMSummerSchool17

# Instrumentation

```
$ cat /tmp/f.cpp 
enum foo {
  a = 0,
  b = 1,
  c = 3
};

int load(foo *f) {
  return *f;
}

int loadb(bool *f) {
  return *f;
}
```
```
$ ~/install-debug/bin/clang++ -O3 -S -emit-llvm -o - /tmp/f.cpp
```

Note that there's range metadata on the bool load, but not the enum load. You need a command line flag to enable range metadata on enums. First, figure out what it is. Look for `MD_range` in Clang's lib/CodeGen/CGExpr.cpp

Next, to detech storing out-of-range values to an enum, we need to modify Clang to emit range metadata on stores in addition to loads. Can you figure out how to do it? The obvious hint is that there's a EmitStoreOfScalar which is very much like EmitLoadOfScalar.

Clang does not emit range metadata on loads at -O0, but rather, only at higher optimization levels. You'll want it to emit the range metadata on stores at all optimization levels for your instrumentation pass.

You can test your code by adding the following two functions to the source file above:

```
void load(foo f, int *s) {
 *s = f;
}

void loadb(bool f, int *s) {
 *s = f;
}
```

To add a new pass to LLVM, you can use the patch: [sample-pass.patch](https://raw.githubusercontent.com/hfinkel/llvm-ss-2017/master/sample-pass.patch)

Note that the patch adds:

```
static cl::opt<bool>
  RunExampleEarly("run-ss-example-early", cl::init(false), cl::Hidden,
    cl::desc("Run the summer-school example early"));
```

to the lib/Transforms/IPO/PassManagerBuilder.cpp.

By passing -mllvm -run-ss-example-early to clang, experiment with the difference between running early and late. Can you construct an example where you "miss" a faulty program when running late in the pipeline? Can you construct a benchmark which runs much faster when the instrumentation is done late?

You might also find it useful to experiment with the -mllvm -print-after-all flag and -mllvm -debug (along with the DEBUG macros).

What should you do when your instrumentation detects an error? One option is to trap (see BoundsChecking::getTrapBB in lib/Transforms/Instrumentation/BoundsChecking.cpp for an example of how to do this). You might also want to print an error message. To do this, you might find the emitPutS in include/llvm/Transforms/Utils/BuildLibCalls.h and CreateGlobalString from include/llvm/IR/IRBuilder.h useful. You'll also want to construct an IRBuilder object. Given some `Instruction *I`, you can use:

```
  IRBuilder<> Builder(I);

```

Also, if you're looking at lib/Transforms/Instrumentation/BoundsChecking.cpp for an example of how to split the basic block to insert the check, note that there is now a common utility to do what BoundsChecking::emitBranchToTrap does: SplitBlockAndInsertIfThen. You can use it like this (and there are many examples in lib/Transforms/Instrumentation/AddressSanitizer.cpp):

```
    Value *NoFakeStack =
        IRB.CreateICmpEQ(FakeStack, Constant::getNullValue(IntptrTy));
    Term = SplitBlockAndInsertIfThen(NoFakeStack, InsBefore, false);
    IRBIf.SetInsertPoint(Term);
```

Also, you might want to look for `MD_range` in lib/Analysis/ScalarEvolution.cpp to see how to use the existing methods for reading the range metadata.

