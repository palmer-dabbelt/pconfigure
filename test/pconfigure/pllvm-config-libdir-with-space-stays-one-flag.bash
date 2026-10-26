#include "harness_start.bash"

# An LLVM unpacked under a directory with a space in its name.  The
# "-L" and "-Wl,-R" pllvm-config --libs adds are flags it writes
# itself, out of "llvm-config --libdir", so they are the one part of
# its answer it can spell for the shell that runs the link -- the way
# pkg-config spells a space in a Libs path as "\ ".  Pasting the
# directory in bare, and then splitting the whole answer at spaces,
# gave the link "-L/opt/my" and a stray word "llvm/lib", which the
# compiler driver reads as the name of an input file.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF2'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--libs)    echo "-lLLVM-15" ;;
--libdir)  echo "/opt/my llvm/lib" ;;
esac
EOF2
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

"$llvm" --libs >libs.out
cat libs.out

# Read back the way a recipe would read it: the shell splits what was
# printed into words, and every word has to be a flag.
eval "set -- $(cat libs.out)"
for word in "$@"
do
    case "$word" in
    -*) ;;
    *)
        echo "stray word '$word' on the link line"
        exit 1
        ;;
    esac
done

# The directory survives whole in both flags, and what llvm-config
# itself said is passed along as it said it.
printf '%s\n' "$@" >words.out
cat >words.expected <<'EOF2'
-lLLVM-15
-lclang
-L/opt/my llvm/lib
-Wl,-R/opt/my llvm/lib
EOF2
diff -u words.expected words.out
