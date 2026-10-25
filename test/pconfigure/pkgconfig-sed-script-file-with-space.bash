#include "harness_start.bash"

# "-Sfile" on a pkgconfig LIBRARY, in the manual's words, "runs sed
# with the contents of that file as an argument".  The recipe used to
# do that with an unquoted backtick, so the shell split the contents
# at every space: an "s/@@VERSION@@/1.0 beta/" became the expression
# "s/@@VERSION@@/1.0" (which sed calls unterminated) and a file named
# "beta/".  A space is an ordinary character in a sed replacement and
# in a pkg-config Version, so a script that writes one is not doing
# anything unusual.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += -Sversion.sed
SOURCES     += x.pc
EOF

cat >version.sed <<'EOF'
s/@@VERSION@@/1.0 beta/
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: @@VERSION@@
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^Version: 1.0 beta$" obj/pkgconfig/x.pc

make $MAKE_ARGS
for pc in lib/pkgconfig/x.pc obj/pkgconfig/x.pc
do
    cat $pc
    grep -q "^Version: 1.0 beta$" $pc
done
