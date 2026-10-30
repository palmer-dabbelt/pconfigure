test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# Taking a DEPLIBS away has to relink the binary that named it.  The
# manual says a DEPLIBS is a "LINKOPTS += -l" and nothing more, and a
# LINKOPTS that changes moves the link into a directory named after the
# hash of the link options -- so the link runs again because its target
# is new.  A DEPLIBS has to be in that hash as well, because taking
# one away only removes a prerequisite, which is never a reason for
# make to rebuild anything: without the hash moving, the binary goes
# on depending on the library nobody asked for any more.
#
# --no-as-needed keeps the linker from tidying the dependency away on
# its own, so the NEEDED entry says exactly what the link line asked
# for.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

BINARIES  += app
LINKOPTS  += -Wl,--no-as-needed
DEPLIBS   += one
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
readelf -d bin/app > first.dyn
cat first.dyn
grep -q "NEEDED.*libone.so" first.dyn

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The DEPLIBS goes away                                                      #
##############################################################################
sleep 2
cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

BINARIES  += app
LINKOPTS  += -Wl,--no-as-needed
SOURCES   += main.c
EOF

make $MAKE_ARGS > second.out 2>&1
cat second.out
grep -q "^PCONFIGURE$" second.out

# The binary was linked again, without the library.
grep -q "^LD	app$" second.out
readelf -d bin/app > second.dyn
cat second.dyn
if grep -q "NEEDED.*libone.so" second.dyn
then
    exit 1
fi
