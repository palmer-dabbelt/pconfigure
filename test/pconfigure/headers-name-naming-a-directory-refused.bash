#include "harness_start.bash"

# A HEADERS whose name is "." -- or a directory followed by "/." or
# "/.." -- names the include directory, or a directory in it, rather
# than a header.  There is no file to copy there or to install, and
# taking the last component off to make one up would be guessing, so
# it is refused while configuring and names the line, the way the
# same spellings of a BINARIES are.
mkdir -p include/sub
echo 'int a;' > include/sub/a.h

for name in . ./ sub/. sub/./ sub/a.h/.. sub/a.h/../
do
    rm -rf Makefile obj
    cat >Configfile <<EOF2
LANGUAGES += c

HEADERS   += $name
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        echo "HEADERS += $name was accepted" >&2
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:3 'HEADERS += $name'" configure.out
    grep -qF "names a directory" configure.out
    grep -qF "like 'HEADERS += main.h'" configure.out
done
