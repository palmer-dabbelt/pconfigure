#include "harness_start.bash"

# A HEADERSRC copies src/x.h to include/x.h, which makes include/x.h
# build output: the copy is written over whenever src/x.h is newer,
# while configuring as well as by make, and "make distclean" removes
# it by name.  When include/x.h is already there as a header somebody
# wrote, that header is either overwritten by the first configure or,
# if it happens to be newer, compiled against in place of the one the
# Configfile named -- and then deleted by distclean, which nothing can
# undo.  The collision is visible while configuring, so it is refused
# there, naming the line and leaving the header alone.
#
# The same holds for the two-line spelling, a HEADERS with a SOURCES
# under it, whose advice is to delete the SOURCES rather than to write
# a HEADERS.
mkdir -p src include
echo '#define WHICH 2 /* from src */' > src/x.h

for spelling in headersrc headers
do
    echo '#define WHICH 1 /* hand-written */' > include/x.h
    rm -f Makefile

    case "$spelling" in
    headersrc)
        cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h
EOF
        ;;
    headers)
        cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERS   += x.h
SOURCES   += x.h
EOF
        ;;
    esac

    # The source is made newer than the hand-written header, which is
    # the order that had the configure itself copy over it.
    touch -d '+2 seconds' src/x.h 2>/dev/null || { sleep 2; touch src/x.h; }

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        echo "the $spelling copy onto a hand-written header was accepted" >&2
        exit 1
    fi
    cat configure.out

    grep -qF "Configfile:4 '" configure.out
    grep -q "error: 'include/x.h' is already there" configure.out
    case "$spelling" in
    headersrc)
        grep -qF "Configfile:4 'HEADERSRC += x.h'" configure.out
        grep -qF "write 'HEADERS += x.h' instead" configure.out
        ;;
    headers)   grep -qF "delete the SOURCES under it" configure.out ;;
    esac

    grep -q "hand-written" include/x.h
    test ! -e Makefile
done

exit 0
