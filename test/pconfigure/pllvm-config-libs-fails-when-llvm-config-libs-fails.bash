#include "harness_start.bash"

# An LLVM installed with only its shared library has no static
# component libraries, and "llvm-config --libs core" says so and exits
# non-zero ("llvm-config: error: missing: .../libLLVMCore.a").
# pllvm-config --libs runs that and then pastes "-lclang" and the
# library directory after it, and the status it reports is that of
# the last command substitution on the line rather than of the one
# that failed -- so it prints a link line with no LLVM libraries on it
# and exits 0, and a Configfile backtick that ought to have stopped
# configuring writes a Makefile that fails at link time instead.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--cflags)  echo "-I/opt/llvm/include" ;;
--libs)
    echo "llvm-config: error: missing: /opt/llvm/lib/libLLVMCore.a" >&2
    exit 1
    ;;
--libdir)  echo "/opt/llvm/lib" ;;
esac
EOF
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$llvm" --libs >libs.out 2>libs.err
status="$?"
set -e
cat libs.out libs.err

# The failure is passed on, the way ppkg-config passes on pkg-config's.
test "$status" != "0"
test ! -s libs.out
grep -q "missing: /opt/llvm/lib/libLLVMCore.a" libs.err

# And --optional still turns it into no answer at all, rather than a
# link line that only names libclang.
# llvm-config's complaint is part of the silence --optional asks for.
"$llvm" --optional --libs >optional.out 2>optional.err
test ! -s optional.out
test ! -s optional.err

exit 0
