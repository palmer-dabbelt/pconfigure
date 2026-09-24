#include "harness_start.bash"

# Touching one library between two others relinks the consumers of
# that library and touches nothing else on the link line (taxonomy
# types 1, 10, E).  Two things have to hold at once: the siblings --
# both the untouched libraries and the consumer's own objects -- stay
# exactly as they were, and the *order* of the link line comes out of
# the rebuild the way it went in.  A link line that reshuffles itself
# when one member changes is its own failure mode on top of the
# relink: static-link ordering is semantic, which is why
# multi-static-link.bash exists, and a relink that reorders can turn
# a working link into a broken one with no Configfile change to blame.
#
# The assertions read the link command out of the Makefile before and
# after and compare the text, because the order that matters is the
# one make was given, not the one a rebuild happened to produce.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
DEPLIBS   += one
DEPLIBS   += two
DEPLIBS   += three
SOURCES   += main.c

LIBRARIES += libone.a
SOURCES   += one.c

LIBRARIES += libtwo.a
SOURCES   += two.c

LIBRARIES += libthree.a
SOURCES   += three.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/two.c <<'EOF'
int two(void) { return 2; }
EOF

cat >src/three.c <<'EOF'
int three(void) { return 3; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int one(void);
int two(void);
int three(void);
int main(void) { printf("%d\n", one() + two() + three()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "6"

# The link line, as the Makefile spells it: objects in directory
# order, then the libraries in the order the Configfile named them.
before="$(grep -oE '\-oobj/bin/app/[0-9]*/local obj/src/main\.c/[^ ]*static\.o.*' Makefile)"
test -n "$before"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the touch mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The middle library's source changes                                        #
##############################################################################
sleep 2
printf 'int two(void) { return 20; }\n' > src/two.c

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The touched library's source recompiled and its archive rebuilt ...
grep -q "^CC	two.c$" second.out
grep -q "^LD	libtwo.a$" second.out

# ... the consumer relinked ...
grep -q "^LD	app$" second.out

# ... and its own source did not recompile, and the sibling
# libraries did nothing at all.
if grep -qE "^CC	(main|one|three)\.c$" second.out
then
    exit 1
fi
if grep -qE "^LD	lib(one|three)\.a$" second.out
then
    exit 1
fi

# The link line came out in the order it went in -- same text, same
# order, one member's content changed under it.
after="$(grep -oE '\-oobj/bin/app/[0-9]*/local obj/src/main\.c/[^ ]*static\.o.*' Makefile)"
test "$before" = "$after"

# And the binary answers from the new library.
test "$(./bin/app)" = "24"

exit 0
