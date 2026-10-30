test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# The whole trip a libdir takes: out of pllvm-config, through a
# Configfile's backticks, into a link recipe that make reads before the
# shell does.  The directory has a space, a quote, a "$" and a "#" in
# it -- one for the shell to split at, one for it to pair up, one for
# make to expand and one that would start a comment -- and a non-ASCII
# byte, read in the C locale, that needs no quoting and has to be left
# alone.  The program only links if the "-L" names that directory as
# one word.  A word that came out wrong is a library that isn't found,
# or a stray input file the linker can't open.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

# LLVM goes outside the project, where an LLVM really is.  A "-L" into
# the project's own tree gets a run path of its own, which is a
# different thing from what pllvm-config prints.
lib="$(pwd)/my llvm's \$HOME #1 caf$(printf '\303\251')/lib"
mkdir -p "$lib" fakebin proj/src
printf '%s\n' "$lib" >libdir
cat >fakellvm.c <<'EOF2'
int fake_llvm(void) { return 0; }
EOF2
cc -c fakellvm.c -o fakellvm.o
ar rcs "$lib/libfakellvm.a" fakellvm.o
ar rcs "$lib/libclang.a" fakellvm.o

cat >fakebin/llvm-config <<EOF2
#!/bin/bash
case "\$1" in
--version) echo 15.0.0 ;;
--libs)    echo "-lfakellvm" ;;
--libdir)  cat "$(pwd)/libdir" ;;
esac
EOF2
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

cd proj
cat >src/main.c <<'EOF2'
int fake_llvm(void);
int main(void) { return fake_llvm(); }
EOF2

cat >Configfile <<EOF2
LANGUAGES   += c

BINARIES    += main
LINKOPTS    += \`"$llvm" --libs\`
SOURCES     += main.c
EOF2

LC_ALL=C $PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
./bin/main
