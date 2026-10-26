#include "harness_start.bash"

# A vendored meson tree is installed into its object-directory prefix
# as part of building it, by a "ninja install" that runs "meson
# install" -- which reads DESTDIR from the environment.  make puts
# every variable from its command line into the environment of the
# recipes it runs, so "make DESTDIR=/stage" sent that install to
# /stage/<absolute object prefix> while the stamp recorded it as done
# and obj/sub/prefix stayed empty.  The same DESTDIR written as an
# --env is refused; this is the same install going to the same wrong
# place.

if ! command -v meson > /dev/null || ! command -v ninja > /dev/null
then
    echo "SKIP: no meson or no ninja on the PATH"
    exit 0
fi

mkdir -p sub

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
EOF2

cat >sub/meson.build <<'EOF2'
project('sub', [])
install_data('tool.txt', install_dir: get_option('datadir'))
EOF2
echo tool > sub/tool.txt

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR="$tempdir/stage"

test -f obj/sub/prefix/share/tool.txt
test ! -e "$tempdir/stage"

exit 0
