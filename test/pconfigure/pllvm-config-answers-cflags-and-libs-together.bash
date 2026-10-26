#include "harness_start.bash"

# The manual says pllvm-config "does the same thing as ppkg-config",
# and pkg-config answers "--cflags --libs" with both.  pllvm-config
# used to keep only the last method it was given and silently drop the
# other, so a Configfile line that asked for both (a C++ tool compiled
# and linked from one source, say) lost LLVM's include path or its
# libraries depending on which was written first.  pkg-config always
# puts the cflags ahead of the libs, whatever order they were asked
# in, and answers a repeated method once; ppkg-config passes that
# straight through, so pllvm-config has to give the same answer.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF2'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--cflags)  echo "-I/opt/llvm/include -DNDEBUG" ;;
--libs)    echo "-lLLVM-15" ;;
--libdir)  echo "/opt/llvm/lib" ;;
esac
EOF2
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

libs="-lLLVM-15 -lclang -L/opt/llvm/lib -Wl,-R/opt/llvm/lib"

# Both orders get the same answer, cflags first, with the -DNDEBUG
# dropped.  The words are compared rather than the text, since a
# compile line doesn't care how many spaces sit between them.
"$llvm" --cflags --libs >both.out
cat both.out
test "$(echo $(cat both.out))" = "-I/opt/llvm/include $libs"

"$llvm" --libs --cflags >both2.out
cat both2.out
test "$(echo $(cat both2.out))" = "-I/opt/llvm/include $libs"

# A repeated method is answered once, and the --have define is
# appended once, after everything else.
"$llvm" --cflags --cflags >twice.out
test "$(echo $(cat twice.out))" = "-I/opt/llvm/include"

"$llvm" --have LLVM --libs --cflags >have.out
test "$(echo $(cat have.out))" = "-I/opt/llvm/include $libs -DHAVE_LLVM"

# An unknown method next to a good one is still refused, rather than
# lost behind the good one's output.
set +e
"$llvm" --cflags --ldflags >unknown.out 2>unknown.err
status="$?"
set -e
test "$status" != "0"
test ! -s unknown.out
grep -q "Unsupported method --ldflags" unknown.err

# No method at all is refused by name, since an empty answer reads as
# an LLVM that needs no flags.
set +e
"$llvm" --have LLVM >none.out 2>none.err
status="$?"
set -e
test "$status" != "0"
test ! -s none.out
grep -q "No method given" none.err

exit 0
