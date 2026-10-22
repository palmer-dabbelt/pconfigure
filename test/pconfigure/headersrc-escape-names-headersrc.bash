#include "harness_start.bash"

# HEADERSRC is the other command that is two commands wearing one
# hat, a HEADERS and a SOURCES, and so the other one whose escaping
# path is refused by the SOURCES half.  A diagnostic that names a
# command the Configfile doesn't have sends whoever reads it looking
# for a line that isn't there, and one that suggests a SOURCES line
# suggests something that would no longer install the header.
mkdir -p src include
echo 'int f(void) { return 0; }' > src/f.c

for path in "../x.h" "/abs/x.h" '$(HOME)/x.h'
do
    cat >Configfile <<EOF2
LANGUAGES += c

LIBRARIES += libf.so
SOURCES   += f.c
HEADERSRC += $path
EOF2
    cat Configfile
    rm -f Makefile

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        echo "HEADERSRC += $path was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:5" out
    grep -q "error: HEADERSRC names a file outside this project" out
    grep -q "like 'HEADERSRC += " out
    if grep -q "SOURCES names\|'SOURCES +=" out
    then
        echo "HEADERSRC += $path was reported as a SOURCES" >&2
        exit 1
    fi
    test ! -e Makefile
done
