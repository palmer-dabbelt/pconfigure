#include "harness_start.bash"

# What a static library is for: its code is copied into the program
# that links it, and the program never looks for the library again.
# A binary that DEPLIBS a "libone.a" has to run with the library gone,
# and must not ask for it at run time -- a NEEDED entry naming
# "libone.a" is a program that goes looking for an archive at run
# time, which no loader will ever find installed anywhere.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.a
SOURCES   += one.c

BINARIES  += app
DEPLIBS   += one
SOURCES   += main.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int one(void);
int main(void) { printf("%d\n", one()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# The run-time libraries a file asks for are its NEEDED entries in ELF
# and its load commands in Mach-O, and each format has its own tool to
# list them: stock macOS has no readelf.
if [[ "$(uname -s)" == "Darwin" ]]
then
    otool -L bin/app > app.dyn
else
    readelf -d bin/app > app.dyn
fi
cat app.dyn
if grep -q "libone" app.dyn
then
    exit 1
fi

rm lib/libone.a
test "$(./bin/app)" = "1"
