#include "harness_start.bash"

# A static archive's members get copied into whatever links it, and
# that isn't always a program: a shared library that DEPLIBS a
# "libone.a" carries its code from then on.  For that to link at all
# the archive's objects have to be position-independent -- a
# non-PIC object referring to its own data can't go into a shared
# object on most machines -- and once it has, nothing at run time
# should go looking for the archive.
#
# The data reference is what makes the PIC question bite: a function
# that only returns a constant links into a shared object either way.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.a
SOURCES   += one.c

LIBRARIES += libtwo.so
DEPLIBS   += one
SOURCES   += two.c

BINARIES  += app
DEPLIBS   += two
SOURCES   += main.c
EOF

cat >src/one.c <<'EOF'
int one_value = 1;
int one(void) { return one_value; }
EOF

cat >src/two.c <<'EOF'
int one(void);
int two(void) { return one() + 1; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int two(void);
int main(void) { printf("%d\n", two()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

test "$(head -c 8 lib/libone.a)" = '!<arch>'
test "$(./bin/app)" = "2"

# The shared library took the archive's code in, rather than leaving a
# reference to it for the loader.
# The run-time libraries a file asks for are its NEEDED entries in ELF
# and its load commands in Mach-O, and each format has its own tool to
# list them: stock macOS has no readelf.
if [[ "$(uname -s)" == "Darwin" ]]
then
    otool -L lib/libtwo.so > two.dyn
else
    readelf -d lib/libtwo.so > two.dyn
fi
cat two.dyn
if grep -q "libone" two.dyn
then
    exit 1
fi

rm lib/libone.a
test "$(./bin/app)" = "2"
