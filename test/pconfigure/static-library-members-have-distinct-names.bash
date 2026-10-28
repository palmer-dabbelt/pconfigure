#include "harness_start.bash"

# An archive names each member after the last component of the path
# it was added from, and every object pconfigure compiles is called
# "<option hash>-shared.o" in a directory named after its source.  Put
# into "ar" as they are, every source of a library becomes a member of
# the same name: the link still works, through the symbol index, but
# "ar x" on the library leaves one object standing out of several, and
# "ar d" on a member name deletes whichever it finds first.
#
# So this asks for what a person handed the archive would: that "ar t"
# lists as many different names as the library has sources, and that
# "ar x" gives every one of their objects back.  Two of the sources
# share a file name from different directories, which is the one case
# naming a member after its source alone doesn't cover.

mkdir -p src/sub

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.a
SOURCES   += one.c
SOURCES   += extra.c
SOURCES   += sub/one.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 2; }
EOF

cat >src/sub/one.c <<'EOF'
int sub_one(void) { return 3; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

# macOS's ar keeps its symbol index as a member of its own, called
# "__.SYMDEF" or "__.SYMDEF SORTED", which "ar t" lists and "ar x"
# extracts like any other.  It isn't one of the library's objects, so
# it's left out of the counting.
ar t lib/libone.a | grep -v '^__\.SYMDEF' > members
cat members
test "$(wc -l < members | tr -d ' ')" = 3
test "$(sort -u members | wc -l | tr -d ' ')" = 3

mkdir extracted
(cd extracted && ar x ../lib/libone.a && rm -f __.SYMDEF*)
ls extracted
test "$(ls extracted | wc -l | tr -d ' ')" = 3

# Mach-O spells a C function's symbol with a leading underscore, ELF
# doesn't.  A defined function is a "T" either way, and an undefined
# reference a "U", so no option is needed to tell them apart -- which
# matters because Apple's older nm doesn't take GNU's --defined-only.
nm extracted/* > symbols
cat symbols
grep -q " T _\?one$" symbols
grep -q " T _\?extra$" symbols
grep -q " T _\?sub_one$" symbols
