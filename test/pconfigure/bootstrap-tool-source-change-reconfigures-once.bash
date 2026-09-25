#include "harness_start.bash"

# A tree that bootstraps its own pconfigure has the tool's source in
# its own tree, and the tool's binary at the end of a rule like any
# other binary's -- after the first bootstrap, the vendored tree is
# "an ordinary subproject" in the words of the Makefile's own comment.
# Which means an edit to the vendored pconfigure's own source is the
# llvm-tblgen shape once removed: the tool relinks through the
# ordinary graph, and -- the part this test exists to pin -- the tree
# that the tool is the brain of reconfigures exactly once with the
# new tool, then settles (taxonomy type 2, 8, B).
#
# The failure shape on the other side of "once" is the loop: a
# reconfigure that rewrites the Makefiles on every build, each rewrite
# newer than the last thing built.  The stand-in pconfigure writes
# both of its observable actions to files, one line per event, so the
# counts below are the whole story: bootstrap runs never (after the
# fresh checkout), reconfigures once, and a make after that has
# nothing to do.
#
# The stand-in is a bash script wrapper around the suite's own
# pconfigure, with a bootstrap.sh that compiles it the way the bash
# language does.  The vendored Configfile names the wrapper's source;
# the tree's Configfile points BOOTSTRAP at the vendored tree.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"
here="$PWD"

mkdir -p src vendor/pconfigure/src

cat >vendor/pconfigure/src/pconfigure.bash <<EOF
echo ran >> "$here/configures"
exec "$(dirname "$PTEST_BINARY")/pconfigure" "\$@"
EOF

cat >vendor/pconfigure/Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

cat >vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
echo ran >> "$here/bootstraps"
mkdir -p bin
{ echo "#!/bin/bash"; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOF
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOF
AUTORECONFIGURE  = true
BOOTSTRAP        = vendor/pconfigure

LANGUAGES       += c

BINARIES        += hello
SOURCES         += hello.c
EOF

cat >src/hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

# Committed Makefile first, fresh checkout second: the bootstrap
# Makefile is what make reads when there is no Makefile.pconfigure to
# include, and the bootstrap runs exactly once into that shape.
$PTEST_BINARY $PCONFIGURE_ARGS
cp Makefile Makefile.committed
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

make $MAKE_ARGS > first.out 2>&1
cat first.out
./bin/hello

test "$(wc -l < bootstraps)" -eq 1
test "$(wc -l < configures)" -eq 1

# And the build has nothing to do from here on.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The vendored tool's own source changes                                     #
##############################################################################
sleep 2
echo "# edited" >> vendor/pconfigure/src/pconfigure.bash

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The tool rebuilt -- not by bootstrap.sh, which has no reason to run
# again, but through the ordinary subproject graph the bootstrap left
# behind ...
test "$(wc -l < bootstraps)" -eq 1
grep -q "^BASH	pconfigure$" second.out

# ... and the tree reconfigured exactly once with the new tool: the
# new brain has not written anything down yet, and a build that
# leaves the counts here where they started is a build whose rebuilt
# tool sits unused.  Unweakened: this is what correct incremental
# behavior looks like, and the test fails while the build settles for
# a relink.
test "$(wc -l < configures)" -eq 2

# And then it settles -- the "once" in the name is the point, and a
# loop would answer this make with another configure instead of
# nothing.
make $MAKE_ARGS > third.out 2>&1
cat third.out
grep -q "Nothing to be done" third.out
test "$(wc -l < configures)" -eq 2
test "$(wc -l < bootstraps)" -eq 1

exit 0
