#include "harness_start.bash"

# A pkgconfig LIBRARY is one template run through sed, so it has room
# for exactly one SOURCES -- the same as a BASH or a perl target, both
# of which refuse a second one and say what to write instead.  The
# pkgconfig language used to take the first and drop the rest without
# a word: the second file was made a prerequisite, so editing it
# rebuilt the .pc, but nothing in it ever reached the output.  Here
# that would have been the "Libs:" line, and every consumer would have
# linked without the library.
#
# Every fatal error ends in abort(), so the exit status alone says
# nothing about which one this was; the message is what's checked.
# The second SOURCES is not on the line after the first, so a message
# naming the wrong line can't pass.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
SOURCES     += head.pc
COMPILEOPTS += s/@@X@@/x/
SOURCES     += libs.pc
EOF

cat >src/head.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
EOF

cat >src/libs.pc <<'EOF'
Libs: -L${prefix}/lib -lx
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Configfile:5 'SOURCES += libs.pc'" pconfigure.out
grep -q "'pkgconfig/x.pc' is one pkg-config file made from one template" pconfigure.out
grep -q "already has 'head.pc' from \./Configfile:3" pconfigure.out
grep -q "move what is in libs.pc into head.pc" pconfigure.out
