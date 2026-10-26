#include "harness_start.bash"

# The same leak through the environment rather than the command line:
# a packaging wrapper that exports DESTDIR before running "make" and
# "make install".  The outer Makefile reading $(DESTDIR) from the
# environment for its own install is make doing what it was asked;
# the vendored tree's build-time install reading it too is not, since
# that install is part of building and has to land in the object
# directory's prefix for anything else in the build to find it.

mkdir -p sub

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
EOF2

cat >sub/configure <<'EOF2'
#!/bin/sh
prefix=
for a in "$@"
do
    case "$a" in --prefix=*) prefix="${a#--prefix=}";; esac
done
printf 'all:\n\techo tool > tool\ninstall:\n\tmkdir -p $(DESTDIR)%s/bin\n\tcp tool $(DESTDIR)%s/bin/tool\n' "$prefix" "$prefix" > Makefile
EOF2
chmod +x sub/configure

$PTEST_BINARY $PCONFIGURE_ARGS
DESTDIR="$tempdir/stage" make $MAKE_ARGS

test -f obj/sub/prefix/bin/tool
test ! -e "$tempdir/stage"

exit 0
