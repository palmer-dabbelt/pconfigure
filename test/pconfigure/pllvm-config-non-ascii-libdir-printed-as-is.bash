#include "harness_start.bash"

# A libdir that needs no quoting comes out exactly as llvm-config
# printed it, whatever bytes are in it.  That includes non-ASCII ones
# read in the C locale: bash's printf %q spells each of those as
# $'\303\251', and make, which reads the backticks' output before any
# shell does, takes "$'" for a variable named "'".  The link was then
# handed one quoted word full of backslashes where its -L and -Wl,-R
# should have been.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF2'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--libs)    echo "-lLLVM-15" ;;
--libdir)  printf '/opt/caf\303\251-1.0_x+y=z,w@v%%u/lib\n' ;;
esac
EOF2
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

LC_ALL=C "$llvm" --libs >libs.out
cat libs.out

dir="$(printf '/opt/caf\303\251-1.0_x+y=z,w@v%%u/lib')"
printf '%s\n' "-lLLVM-15 -lclang -L$dir -Wl,-R$dir" >libs.expected
cmp libs.expected libs.out
