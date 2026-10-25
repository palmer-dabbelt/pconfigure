#include "harness_start.bash"

# "make -n" on a tree that has been configured but never built should
# print what a build would do and exit 0.  A vendored autotools tree
# is built by a recursive "$(MAKE) -C obj/<tree>/build", and make runs
# a line with $(MAKE) in it even under -n so the sub-make can say what
# it would do.  But the line that runs configure, which is what makes
# that build directory, is an ordinary line and is only printed -- so
# the sub-make is started in a directory that doesn't exist, and the
# dry run fails with "No such file or directory" instead of describing
# the build.

mkdir -p sub

cat >Configfile <<'EOF'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
EOF

# Just enough of a configure: it writes the Makefile the build runs.
cat >sub/configure <<'EOF'
#!/bin/sh
printf 'all:\n\techo built > built\ninstall:\n\ttrue\n' > Makefile
EOF
chmod +x sub/configure

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS -n > dry.out 2>&1 || { cat dry.out; exit 1; }
cat dry.out

# It printed the configure rather than running it.
test ! -e obj/sub/build/Makefile

# And the real build still works afterwards.
make $MAKE_ARGS
test -f obj/sub/build/built

# Once the build directory does exist, a dry run still goes into it:
# the sub-make under -n is what says what the tree's own build would
# do, which is the part of the answer worth asking for.  A source
# newer than the stamp is what sends make back into the tree.
rm obj/sub/build/built
sleep 1
touch sub/configure
make $MAKE_ARGS -n > dry2.out 2>&1 || { cat dry2.out; exit 1; }
cat dry2.out
grep -q 'echo built > built' dry2.out
test ! -e obj/sub/build/built

exit 0
