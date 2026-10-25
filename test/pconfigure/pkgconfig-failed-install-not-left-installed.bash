#include "harness_start.bash"

# The installed .pc used to be written the same way as the one in the
# tree: straight into "$(DESTDIR)$PREFIX/lib/pkgconfig/x.pc" by a
# redirect.  When its sed failed, "make install" failed -- but the
# redirect had already made an empty file there, and that file is the
# install target.  So a second "make install" found it up to date,
# said there was nothing to do and exited 0, leaving an empty .pc
# installed where a consumer's pkg-config would read it.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/^Version: 1/Version: 2
SOURCES     += x.pc
EOF2

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

for attempt in first second
do
    if make $MAKE_ARGS DESTDIR=$tempdir/dest install
    then
        find dest -ls || true
        echo "the $attempt install of a failing .pc succeeded" >&2
        exit 1
    fi

    # Nothing at all goes under the prefix for it: not an empty .pc,
    # and not the half-written one it was being made out of either,
    # which "make uninstall" would never know to take back out.
    if test -n "$(find dest -name 'x.pc*' 2>/dev/null)"
    then
        find dest -ls
        echo "the $attempt failed install left a .pc under the prefix" >&2
        exit 1
    fi
done
