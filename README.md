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

Note that the patch adds:

```
static cl::opt<bool>
  RunExampleEarly("run-ss-example-early", cl::init(false), cl::Hidden,
    cl::desc("Run the summer-school example early"));
```

to the lib/Transforms/IPO/PassManagerBuilder.cpp.

By passing -mllvm -run-ss-example-early to clang, experiment with the difference between running early and late. Can you construct an example where you "miss" a faulty program when running late in the pipeline? Can you construct a benchmark which runs much faster when the instrumentation is done late?

You might also find it useful to experiment with the -mllvm -print-after-all flag and -mllvm -debug (along with the DEBUG macros).

