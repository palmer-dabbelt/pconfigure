#include "harness_start.bash"

# headers-source-switch-recopies-header covers moving a HEADERS from
# one source to another.  Moving it back is the case a name-hashed
# output would get wrong, because the first source is older than the
# copy the second one made; the copy is rebuilt from its recorded
# command instead, so going back is a change like any other.

mkdir -p src

echo '/* first */' > src/first.h
echo '/* second */' > src/second.h

configure_with() {
    cat >Configfile <<EOC
LANGUAGES += c
LANGUAGES += h

HEADERS   += pub.h
SOURCES   += $1
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with first.h
make $MAKE_ARGS
diff -u src/first.h include/pub.h

sleep 2
configure_with second.h
make $MAKE_ARGS
diff -u src/second.h include/pub.h

sleep 2
configure_with first.h
grep -q "^include/pub.h: src/first.h" Makefile
make $MAKE_ARGS
diff -u src/first.h include/pub.h

make $MAKE_ARGS DESTDIR=$(pwd)/stage install
diff -u src/first.h stage/usr/local/include/pub.h

# Having caught up, the copy is not made again on every make.
make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log
