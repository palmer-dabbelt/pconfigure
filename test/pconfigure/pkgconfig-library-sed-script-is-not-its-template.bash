#include "harness_start.bash"

# A "-S" on a pkgconfig LIBRARY names a file of sed commands to run
# over the .pc template, which makes the script a prerequisite of the
# .pc as well.  It used to be pushed onto the same list the SOURCES
# were on, and the template was "whatever is first on that list", so
# a LIBRARY whose SOURCES were forgotten did not have nothing to build:
# it had the sed script, which it ran through sed and installed as the
# .pc.  pconfigure warned that the target "has nothing to build" and
# then built it anyway, out of the wrong file.
#
# Now the sed script is only ever a sed script, so this is the same as
# a LIBRARY with no SOURCES at all: the warning at configure time, and
# a rule that fails at make time instead of writing a .pc.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += -Sversion.sed
EOF

cat >version.sed <<'EOF'
s/@@VERSION@@/1.0/
EOF

$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
cat stderr
grep -q "Configfile:2 'LIBRARIES += pkgconfig/x.pc'" stderr
grep -q "has nothing to build" stderr
test ! -e obj/pkgconfig/x.pc

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "Configfile:2: pkgconfig/x.pc has no SOURCES to be made from" make.out
test ! -e lib/pkgconfig/x.pc
