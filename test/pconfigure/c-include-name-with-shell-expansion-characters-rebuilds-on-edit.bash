#include "harness_start.bash"

# A header's name only ever reaches make, never a shell: it is a
# prerequisite of the object, and the compile recipe names the source
# rather than the header.  So the characters that bash would expand or
# act on in a recipe -- braces, a backtick, '&', a quote, parentheses
# -- are harmless in the name of a header that has no source behind
# it, and such a header builds and is rebuilt after an edit like any
# other, with the scan at configure time or under AUTORECONFIGURE.
top="$tempdir"
n=0
for name in 'b{x,y}' 'b{1..2}' 'c`true`d' 'e&f' "g'h" 'i(j)k' 'l^m,n' '-o'
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
