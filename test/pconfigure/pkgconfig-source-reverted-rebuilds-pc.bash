#include "harness_start.bash"

# A pkgconfig LIBRARY switched to another template and then back: the
# first template is older than the .pc the second one wrote, so only
# the record of the recipe can say the file is out of date.  Both the
# tree's copy and the installed one have to come back to the first
# template's text.

mkdir -p src

echo 'Name: first' > src/first.pc
echo 'Name: second' > src/second.pc

configure_with() {
    cat >Configfile <<EOC
LANGUAGES += pkgconfig
LIBRARIES += pkgconfig/v.pc
SOURCES   += $1
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with first.pc
make $MAKE_ARGS
grep -q '^Name: first$' lib/pkgconfig/v.pc

sleep 2
configure_with second.pc
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/stage install
grep -q '^Name: second$' lib/pkgconfig/v.pc
grep -q '^Name: second$' stage/usr/local/lib/pkgconfig/v.pc

sleep 2
configure_with first.pc
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/stage install
grep -q '^Name: first$' lib/pkgconfig/v.pc
grep -q '^Name: first$' stage/usr/local/lib/pkgconfig/v.pc

# Having caught up, the build settles rather than redoing it each time.
make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log
