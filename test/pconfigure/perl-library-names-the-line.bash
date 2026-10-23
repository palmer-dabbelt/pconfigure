#include "harness_start.bash"

# BASH declines a LIBRARIES target, so a project that asks for a
# library out of .bash sources is told no language can build it, and
# told which line asked.  Perl builds through the very same code, but
# used to claim anything whose sources end in .pl, LIBRARIES included,
# and hand it on to a targets() with no case for a library -- which
# printed "Unimplemented context type" and aborted without a word of
# which Configfile it was about.
#
# Both ways end in abort(), which is how every fatal error here stops,
# so the exit status can't tell them apart: what the message says is
# the whole of the difference.  The library is deliberately not on the
# first line, so a message that names the wrong one can't pass.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += perl

LIBRARIES   += libtool.so
SOURCES     += tool.pl
EOF

cat >src/tool.pl <<'EOF'
print "tool\n";
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Unable to find language for ./Configfile:3 'LIBRARIES += libtool.so'" pconfigure.out
if grep -q "Unimplemented context type" pconfigure.out
then
    exit 1
fi
