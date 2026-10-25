#include "harness_start.bash"

# Every COMPILEOPTS on a pkgconfig LIBRARY that isn't a "-S" is, in
# the manual's words, run through "sed with that as an argument".  It
# used to be pasted into the recipe between a pair of single quotes
# with nothing done about a single quote inside it, so an expression
# with an apostrophe in it closed the quoting early and left the shell
# an unterminated string.  pconfigure runs that recipe itself at
# configure time, to build the copy consumers are answered out of, and
# only warned; make then failed on the same line.
#
# A sed expression is allowed to contain any character, and a .pc
# Description is exactly the sort of free text somebody wants to fill
# in this way.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/@@DESCRIPTION@@/the project's library/
SOURCES     += x.pc
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: @@DESCRIPTION@@
Version: 1
EOF

$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
cat stderr

# The configure-time build of the build-tree copy ran the same
# command, so it has to be there and right before make has run at all.
grep -q "^Description: the project's library$" obj/pkgconfig/x.pc

make $MAKE_ARGS
grep -q "^Description: the project's library$" lib/pkgconfig/x.pc
grep -q "^Description: the project's library$" obj/pkgconfig/x.pc
