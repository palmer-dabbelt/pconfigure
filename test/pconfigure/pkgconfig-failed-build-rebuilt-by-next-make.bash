#include "harness_start.bash"

# A .pc that failed to build has to be tried again by the next make.
# The recipe used to redirect straight into the target, so the shell
# created the file before sed had even looked at its expression; when
# sed then refused it, the rule failed but left an empty .pc behind,
# newer than everything it depends on.  The next "make" called that up
# to date and passed, and from then on the tree held an empty .pc that
# nothing would ever rebuild.  Both copies are made by a rule like
# that: the one under lib/ that gets installed, and the build-tree one
# under obj/ that other projects in the build read.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/^Version: 1/Version: 2
SOURCES     += x.pc
EOF2

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
EOF2

# The configure-time copy of the build-tree .pc fails the same way,
# which configure doesn't stop over: make is where that gets reported.
$PTEST_BINARY $PCONFIGURE_ARGS

for pc in lib/pkgconfig/x.pc obj/pkgconfig/x.pc
do
    if make $MAKE_ARGS $pc
    then
        echo "an unterminated sed expression built $pc" >&2
        exit 1
    fi

    # Nothing has changed since, so the second make must fail the same
    # way rather than take a leftover file for a finished one.
    if make $MAKE_ARGS $pc
    then
        ls -l $pc
        echo "the second make took the failed build's $pc as done" >&2
        exit 1
    fi

    # Nor are the half-written copies it was being made out of left
    # lying around beside it, whatever they happen to be called.  The
    # record of its recipe is the one file that belongs there: configure
    # wrote that, not the failed build, and it's what notices the fix.
    if test -n "$(find $(dirname $pc) -name "$(basename $pc)*" \
                  ! -name "$(basename $pc).recipe-inputs" 2>/dev/null)"
    then
        ls -l $pc*
        echo "a failed build of $pc left a file behind" >&2
        exit 1
    fi
done

# And once the expression is fixed, the next make writes the real thing.
sed -i 's@^COMPILEOPTS.*@COMPILEOPTS += s/^Version: 1/Version: 2/@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS lib/pkgconfig/x.pc obj/pkgconfig/x.pc
for pc in lib/pkgconfig/x.pc obj/pkgconfig/x.pc
do
    cat $pc
    grep -q "^Version: 2$" $pc
done
