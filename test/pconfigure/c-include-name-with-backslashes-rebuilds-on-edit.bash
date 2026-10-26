#include "harness_start.bash"

# A backslash on a make rule line escapes a following '#', ':' or
# space, and make reads a run of them in front of one of those as
# escapes of each other, so a header's name is written with each run
# doubled where it has to be and left alone where it doesn't.  Pinned
# here for the three shapes that matter: one in the middle ('a\b.h'),
# one in front of a '#' ('a\#b.h', where the '#' would otherwise start
# a comment) and one at the very end of the stem ('ab\.h').  Each
# builds, and an edit to it rebuilds, in both kinds of scan.
top="$tempdir"
n=0
for name in 'a\b' 'a\#b' 'ab\'
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
