#include "harness_start.bash"

# A version script handed over as the word after its flag rather than
# stuck on with an '=', which is just as good a spelling to the linker
# and has to be just as much a prerequisite of the link: an edit to the
# script relinks the library and bar() stops being exported.  Through
# "-Xlinker" as well as "-Wl," since those are the two ways the
# compiler driver passes a word through.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libx.so
LINKOPTS  += -Wl,--version-script,src/x.map
SOURCES   += x.c

LIBRARIES += liby.so
LINKOPTS  += -Xlinker --version-script -Xlinker src/y.map
SOURCES   += y.c
EOF

cat >src/x.c <<'EOF'
int foo(void) { return 1; }
int bar(void) { return 2; }
EOF
cp src/x.c src/y.c

cat >src/x.map <<'EOF'
X1 { global: foo; bar; local: *; };
EOF
cp src/x.map src/y.map

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
nm -D --defined-only lib/libx.so | grep -qw bar
nm -D --defined-only lib/liby.so | grep -qw bar

# Far enough in the past that the edit below is newer whatever the
# filesystem's timestamp resolution.
find . -type f -exec touch -d '2000-01-01' {} +

cat >src/x.map <<'EOF'
X1 { global: foo; local: *; };
EOF
cp src/x.map src/y.map

make $MAKE_ARGS
for lib in lib/libx.so lib/liby.so
do
    nm -D --defined-only $lib | grep -qw foo
    if nm -D --defined-only $lib | grep -qw bar
    then
        exit 1
    fi
done
