#include "harness_start.bash"

# pllvm-config takes "-DNDEBUG" out of what llvm-config says, so that
# a project's own asserts aren't switched off by the flags it borrowed
# from LLVM.  It does so with
#
#     sed 's@-DNDEBUG@@g'
#
# which also takes those eight characters off the front of any longer
# define: "-DNDEBUG_ASSERTS=1" comes out as "_ASSERTS=1", a bare word
# the compiler driver reads as the name of an input file.  The same
# substring-for-a-word mistake ppkg-config makes with "-L/usr/lib".
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--cflags)  echo "-I/opt/llvm/include -DNDEBUG -DNDEBUG_ASSERTS=1 -D_GNU_SOURCE" ;;
--libs)    echo "-lLLVM-15" ;;
--libdir)  echo "/opt/llvm/lib" ;;
esac
EOF
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

"$llvm" --cflags >cflags.out
cat cflags.out

# The define it means to drop is dropped ...
if grep -qw -- "-DNDEBUG" cflags.out
then
    exit 1
fi

# ... and nothing else is mangled.
grep -q -- "-DNDEBUG_ASSERTS=1" cflags.out
if grep -q -- " _ASSERTS=1" cflags.out
then
    exit 1
fi
grep -q -- "-D_GNU_SOURCE" cflags.out

exit 0
