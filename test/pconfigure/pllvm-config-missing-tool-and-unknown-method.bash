#include "harness_start.bash"

# pllvm-config's contract: with llvm-config
# missing it fails, unless --optional, when it succeeds and prints
# nothing; a method other than --cflags or --libs is refused; and
# --libs adds libclang plus the library directory as both a -L and a
# runpath, and --have appends the define.  --cflags passes
# llvm-config through minus -DNDEBUG.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

# A PATH with no llvm-config on it, but still a bash and a sed.
mkdir emptybin
for tool in bash sed
do
    ln -s "$(command -v $tool)" emptybin/$tool
done

set +e
PATH="$(pwd)/emptybin" "$llvm" --cflags >missing.out
status="$?"
set -e
test "$status" != "0"
test ! -s missing.out

PATH="$(pwd)/emptybin" "$llvm" --optional --cflags >optional.out
test ! -s optional.out

mkdir fakebin
cat >fakebin/llvm-config <<'EOF'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--cflags)  echo "-I/opt/llvm/include -DNDEBUG" ;;
--libs)    echo "-lLLVM-15" ;;
--libdir)  echo "/opt/llvm/lib" ;;
esac
EOF
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$llvm" --ldflags >unknown.out 2>unknown.err
status="$?"
set -e
test "$status" != "0"
grep -q "Unsupported method --ldflags" unknown.err

# llvm-config's own -DNDEBUG is dropped, so that linking against LLVM
# doesn't switch off the asserts of the project doing the linking.
# The words are compared rather than the text, because removing a flag
# leaves the space that was in front of it, and a compile line doesn't
# care about that.
cflags="$("$llvm" --cflags)"
test "$(echo $cflags)" = "-I/opt/llvm/include"

test "$("$llvm" --have LLVM --libs)" \
    = "-lLLVM-15 -lclang -L/opt/llvm/lib -Wl,-R/opt/llvm/lib -DHAVE_LLVM"

exit 0
