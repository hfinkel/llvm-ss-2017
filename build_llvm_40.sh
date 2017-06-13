#!/bin/sh

# zypper install libedit-devel
# zypper install ncurses-devel
# zypper install libelf-devel
# zypper install patch
# zypper install binutils-devel
# zypper install binutils-gold
# or
# zypper install libedit-devel ncurses-devel libelf-devel patch binutils-devel binutils-gold

MODE="$1"
if [ -z "$MODE" ]; then
  MODE="all"
fi

NP=$(grep '^processor' /proc/cpuinfo | wc -l)

set -o errexit
set -o pipefail

BASEDIR=${HOME}
SRCDIR=${BASEDIR}/src
BUILDDIR=${BASEDIR}/build
INSTALLDIR=${BASEDIR}/install

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}

cd $SRCDIR

DIRS="llvm llvm/tools/clang llvm/tools/lld llvm/tools/lldb llvm/tools/clang/tools/extra llvm/projects/compiler-rt llvm/projects/openmp llvm/projects/libcxx llvm/projects/libcxxabi llvm/projects/test-suite flang"

if [ $MODE = all -o $MODE = checkout ]; then
  for d in $DIRS; do
    case $d in
      llvm/tools/clang/tools/extra)
        url="http://llvm.org/git/clang-tools-extra.git"
        ;;
      llvm/tools/clang)
        url="https://github.com/hfinkel/flang-clang"
        ;;
      flang)
        url="https://github.com/flang-compiler/flang"
        ;;
      *)
        url="http://llvm.org/git/$(basename $d).git"
        ;;
      esac
    if [ ! -d $d ]; then
      (cd $(dirname ./$d) && git clone $url $(basename $d))
    fi

    case $d in
      llvm/tools/clang)
        (cd $d && git checkout flang_release_40)
        ;;
      flang)
        :
        ;;
      *)
        (cd $d && git checkout release_40)
      ;;
    esac
  done
fi

export CPATH="$CPATH:/usr/include/ncurses"

if [ $MODE = all -o $MODE = build ]; then
  mkdir -p ${BUILDDIR}
  cd ${BUILDDIR}

  mkdir -p llvm-stage0
  cd llvm-stage0

  cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLDB_DISABLE_CURSES=ON -DLLDB_DISABLE_PYTHON=ON ${SRCDIR}/llvm
  make -j${NP}

  cd ..

  mkdir -p llvm-stage1
  cd llvm-stage1

  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang++ -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_OMPT_BLAME=ON -DLIBOMP_OMPT_TRACE=ON -DLLVM_BINUTILS_INCDIR=/usr/include -DLLDB_DISABLE_PYTHON=ON -DBUILD_SHARED_LIBS=ON ${SRCDIR}/llvm
  # make -j${NP} check-all
  make -j${NP}
  make -j${NP} install

  # To run the test suite:
  # make -j${NP} test-suite
  # ./bin/llvm-lit -v test-suite-bins/

  cd ..

  mkdir -p flang
  cd flang

  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage1/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage1/bin/clang++ -DCMAKE_Fortran_COMPILER=${BUILDDIR}/llvm-stage1/bin/flang -DLLVM_CONFIG=${BUILDDIR}/llvm-stage1/bin/llvm-config -DFLANG_LIBOMP=${BUILDDIR}/llvm-stage1/lib/libomp.so ${SRCDIR}/flang

  # There's some bug in the parallel build, it seems, for the OpenMP module; try the build twice.
  make -j${NP} || true
  make -j${NP}

  make -j${NP} install

  cd ..

  mkdir -p llvm-stage1-debug
  cd llvm-stage1-debug

  cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=${INSTALLDIR}-debug -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang++ -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_OMPT_BLAME=ON -DLIBOMP_OMPT_TRACE=ON -DLLVM_BINUTILS_INCDIR=/usr/include -DLLDB_DISABLE_PYTHON=ON -DBUILD_SHARED_LIBS=ON -DLLVM_USE_SPLIT_DWARF=ON ${SRCDIR}/llvm
  make -j${NP}
  make -j${NP} install

  cd ..

  mkdir -p flang-debug
  cd flang-debug

  cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=${INSTALLDIR}-debug -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage1/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage1/bin/clang++ -DCMAKE_Fortran_COMPILER=${BUILDDIR}/llvm-stage1/bin/flang -DLLVM_CONFIG=${BUILDDIR}/llvm-stage1-debug/bin/llvm-config -DFLANG_LIBOMP=${BUILDDIR}/llvm-stage1-debug/lib/libomp.so ${SRCDIR}/flang

  # There's some bug in the parallel build, it seems, for the OpenMP module; try the build twice.
  make -j${NP} || true
  make -j${NP}

  make -j${NP} install

  cd ..

  mkdir -p openmp-static
  cd openmp-static

  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang++ -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_OMPT_BLAME=ON -DLIBOMP_OMPT_TRACE=ON -DLIBOMP_ENABLE_SHARED=OFF -DLIBOMP_USE_ITT_NOTIFY=OFF ${SRCDIR}/llvm/projects/openmp
  make -j${NP}
  cp -ai runtime/src/lib*.a ${INSTALLDIR}/lib/
 
  cd ..

  mkdir -p openmp-static-debug
  cd openmp-static-debug

  cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang -DCMAKE_CXX_COMPILER=${BUILDDIR}/llvm-stage0/bin/clang++ -DLIBOMP_OMPT_SUPPORT=ON -DLIBOMP_OMPT_BLAME=ON -DLIBOMP_OMPT_TRACE=ON -DLIBOMP_ENABLE_SHARED=OFF -DLIBOMP_USE_ITT_NOTIFY=OFF ${SRCDIR}/llvm/projects/openmp
  make -j${NP}
  cp -ai runtime/src/lib*.a ${INSTALLDIR}-debug/lib/
 
  cd ..
fi

