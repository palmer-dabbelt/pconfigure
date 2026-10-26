#include "harness_start.bash"

# A vendored autotools tree is installed as part of building it, into
# a prefix under the object directory, because that is where the rest
# of the build looks for what it provides.  That install is a
# "$(MAKE) -C obj/sub/build install", and a DESTDIR on the outer make's
# command line ("make DESTDIR=/stage", the way a packaging script that
# builds and installs in one go writes it) is passed down to it through
# MAKEFLAGS like every other command-line variable.  The tree then
# installs under /stage/<absolute object prefix> instead, the stamp
# says it's installed, and obj/sub/prefix is empty.  pconfigure
# already refuses a DESTDIR written into the Configfile (as a MAKEOPS,
# --make-var or --env) for exactly this reason; one from the command
# line is the same install sent to the same wrong place.

mkdir -p sub

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
EOF2

# Just enough of a configure: the Makefile it writes builds a "tool"
# and installs it under $(DESTDIR) and the --prefix, as automake's do.
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
make $MAKE_ARGS DESTDIR="$tempdir/stage"

test -f obj/sub/prefix/bin/tool
test ! -e "$tempdir/stage"

exit 0
