test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A LIBRARIES name may have a directory in it -- "sub/libfoo.so" is
# built as lib/sub/libfoo.so -- but the directory is where the file
# goes, not part of what it is called.  The soname is the name every
# consumer copies into its NEEDED to find the library again, and ld.so
# reads a NEEDED entry with a '/' in it as a path to open from the
# current directory rather than a name to look up along the runpath
# (elf-soname.bash has the long version of why that matters).  So the
# soname is the file's own name, and nothing else.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += sub/libfoo.so
SOURCES   += foo.c
EOF

echo 'int foo(void) { return 7; }' >src/foo.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

test -f lib/sub/libfoo.so
readelf -d lib/sub/libfoo.so > libfoo.dynamic
cat libfoo.dynamic
grep -q '(SONAME).*\[libfoo\.so\]' libfoo.dynamic
