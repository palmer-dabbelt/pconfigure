#include "harness_start.bash"

# A HEADERS with nothing under it is installed rather than built, and
# its name is pasted onto both include/ (to find it) and
# "$(DESTDIR)/$PREFIX/include" (to install it).  So "../../x.h" reads
# a header from beside the checkout and installs it to
# "$PREFIX/../x.h", which is outside the include directory -- and
# outside $PREFIX altogether once there are enough of them.  It is
# the same path question every other command that names a file is
# asked.
mkdir -p proj/include
echo 'int x;' > x.h

for name in "../../x.h" "/tmp/x.h"
do
    cat >proj/Configfile <<EOF
LANGUAGES += c

HEADERS   += $name
EOF
    cat proj/Configfile
    rm -f proj/Makefile

    if (cd proj && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        cat out
        (cd proj && make $MAKE_ARGS DESTDIR=$tempdir/dest install) || true
        find $tempdir/dest -type f || true
        echo "HEADERS += $name was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:3" out
    grep -q "it climbs out of the project\|it's an absolute path" out
    test ! -e proj/Makefile
done
