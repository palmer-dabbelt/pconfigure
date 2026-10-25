#include "harness_start.bash"

# What "make install" puts under the prefix is for everybody on the
# machine, whoever built it and with whatever umask.  The install
# rules copied the tree's file, mode and all, so a tree checked out
# and built under "umask 077" installed a header as -rw------- and a
# bash script as -rwx--x--x: nobody but the builder can read the
# header, and a script that can't be read can't be run by anyone else
# either.  GNU's install rules give what they install a fixed mode for
# this reason, and so do these now.
#
# This covers what the BASH-like languages install -- a script, a
# header built through "h", and a HEADERS with nothing under it, which
# is installed by a rule of its own.  The compiled things have a test
# of their own beside this one.
(
    umask 077
    mkdir -p src include
    echo 'echo hi' > src/script.bash
    echo 'int built(void);' > src/built.h
    echo 'int plain(void);' > include/plain.h

    cat >Configfile <<'EOF2'
LANGUAGES += bash
LANGUAGES += h

BINARIES  += script
SOURCES   += script.bash

HEADERS   += built.h
SOURCES   += built.h

HEADERS   += plain.h
EOF2

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
)

# The install is done the way a packager or "sudo make install" would
# do it, under an ordinary umask.
umask 022
make $MAKE_ARGS DESTDIR=$tempdir/dest install
ls -l dest/usr/local/bin dest/usr/local/include

# Exactly the modes "install -m 755" and "install -m 644" give: an
# install under a looser umask doesn't get anything group-writable
# either.
test -n "$(find dest/usr/local/bin/script -perm 0755)"
test -n "$(find dest/usr/local/include/built.h -perm 0644)"
test -n "$(find dest/usr/local/include/plain.h -perm 0644)"

# The build tree is the builder's own, though, and what its umask
# said about it still stands there.
test -z "$(find bin/script -perm -0004)"
test -z "$(find include/built.h -perm -0004)"
