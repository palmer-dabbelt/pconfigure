#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A LIBDIR moved onto the directory the project vendors into                 #
##############################################################################
# "make distclean" removes the LIBDIR whole, so a SUBPROJECTS under it
# goes too.  Here the Configfile has said both halves of the collision
# outright -- "LIBDIR = vendor" and "SUBPROJECTS += vendor/dep" -- and
# it is refused, pointing at the SUBPROJECTS line.
#
# Both orders, because the LIBDIR can come after the SUBPROJECTS line
# just as well as before it -- all it has to come before is the
# library it sends to "vendor" -- and a check made where the
# SUBPROJECTS is read would only ever see the LIBDIR that came first.
for order in before after
do
    mkdir -p $top/$order/src $top/$order/vendor/dep/src

    if test "$order" = before
    then
        cat >$top/$order/Configfile <<'EOF'
LIBDIR       = vendor
SUBPROJECTS += vendor/dep

LANGUAGES   += c
LIBRARIES   += libtop.so
SOURCES     += top.c
EOF
        line=2
    else
        cat >$top/$order/Configfile <<'EOF'
SUBPROJECTS += vendor/dep
LIBDIR       = vendor

LANGUAGES   += c
LIBRARIES   += libtop.so
SOURCES     += top.c
EOF
        line=1
    fi

    cat >$top/$order/vendor/dep/Configfile <<'EOF'
LANGUAGES   += c
LIBRARIES   += libdep.so
SOURCES     += dep.c
EOF

    echo 'int dep(void) { return 0; }' > $top/$order/vendor/dep/src/dep.c
    echo 'int top(void) { return 0; }' > $top/$order/src/top.c

    if (cd $top/$order && $PTEST_BINARY $PCONFIGURE_ARGS) \
        > $top/$order.out 2>&1
    then
        cat $top/$order.out
        exit 1
    fi
    cat $top/$order.out
    grep -q "^\./Configfile:$line 'SUBPROJECTS" $top/$order.out
    grep -q "'vendor/dep' is inside 'vendor', where libraries go" \
        $top/$order.out
    test ! -e $top/$order/Makefile
    test -f $top/$order/vendor/dep/Configfile
done

##############################################################################
# And moved off it again                                                     #
##############################################################################
# Which is the way out the error suggests: the libraries go somewhere
# that isn't the vendored tree's parent, and distclean leaves the
# tree where it was.
mkdir -p $top/moved/src $top/moved/vendor/dep/src
cp $top/before/vendor/dep/Configfile $top/moved/vendor/dep/Configfile
cp $top/before/vendor/dep/src/dep.c $top/moved/vendor/dep/src/dep.c
cp $top/before/src/top.c $top/moved/src/top.c

cat >$top/moved/Configfile <<'EOF'
LIBDIR       = libs
SUBPROJECTS += vendor/dep

LANGUAGES   += c
LIBRARIES   += libtop.so
SOURCES     += top.c
EOF

(cd $top/moved && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/moved && make $MAKE_ARGS)
test -f $top/moved/libs/libtop.so

(cd $top/moved && make $MAKE_ARGS distclean)
test ! -e $top/moved/libs/libtop.so
test -f $top/moved/vendor/dep/Configfile
test -f $top/moved/vendor/dep/src/dep.c

exit 0
