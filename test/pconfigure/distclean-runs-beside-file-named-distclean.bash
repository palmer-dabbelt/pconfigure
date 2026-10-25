#include "harness_start.bash"

# "make distclean" is a name and not a file, and every other name the
# generated Makefile answers to -- all, clean, cache-clean, report,
# install, uninstall, reconfigure, check-<suite> -- is said to be one
# with a .PHONY line.  Without it, a file of the same name sitting at
# the top of the tree is an up-to-date target with no prerequisites,
# and make answers "'distclean' is up to date" and removes nothing:
# the one rule whose whole job is to take everything back quietly
# does nothing at all.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF

cat >src/hello.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/hello

# A file called "distclean" is not far-fetched: a notes file, a script
# somebody keeps beside the tree, the output of "make distclean >
# distclean" from a previous attempt.
echo "notes" > distclean

make $MAKE_ARGS distclean
test ! -e bin/hello
test ! -e obj
test ! -e Makefile

# And the file that was in the way is somebody else's: being declared
# a name rather than a file mustn't turn into removing it.
test "$(cat distclean)" = "notes"

exit 0
