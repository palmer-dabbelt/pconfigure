#include "harness_start.bash"

# A header the C scan finds becomes a prerequisite of the object, so
# its name lands on a rule line.  make reads a '%' there as a pattern
# only in a target, and expands '*', '?' and '[...]' in a prerequisite
# against the files that exist -- which for a header that is there
# matches itself.  So a header called 'p%c.h', 'g*b.h', 'q?r.h' or
# 'r[1].h' builds and, the point of the prerequisite, an edit to it
# rebuilds the program, whether the scan runs at configure time or
# under AUTORECONFIGURE during the build.
top="$tempdir"
n=0
for name in 'p%c' 'g*b' 'q?r' 'r[1]'
do
    for autoreconfigure in false true
    do
        n=$((n + 1))
        dir=$top/case$n
        mkdir -p $dir/src
        cd $dir
        echo '#define VALUE 1' > "src/$name.h"
        printf '#include "%s.h"\nint main(void) { return VALUE; }\n' \
            "$name" > src/main.c
        printf 'AUTORECONFIGURE = %s\nLANGUAGES += c\nBINARIES += app\nSOURCES += main.c\n' \
            $autoreconfigure > Configfile

        $PTEST_BINARY $PCONFIGURE_ARGS
        make $MAKE_ARGS
        set +e; ./bin/app; got=$?; set -e
        test "$got" = 1

        sleep 1
        echo '#define VALUE 2' > "src/$name.h"
        make $MAKE_ARGS
        set +e; ./bin/app; got=$?; set -e
        test "$got" = 2

        # And once rebuilt it stays built: a name make read back as
        # some other file, one that is never there, would leave the
        # object out of date on every run instead.
        touch stamp
        make $MAKE_ARGS
        test ! bin/app -nt stamp
    done
done
