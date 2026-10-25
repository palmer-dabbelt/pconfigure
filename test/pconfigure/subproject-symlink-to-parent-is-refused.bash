#include "harness_start.bash"

# "SUBPROJECTS += .." inside a subproject names the project that pulled
# it in, and is refused from above and from inside alike.  The same
# directory reached through a symlink in the subproject -- "up" linking
# to ".." -- is judged on its spelling, which neither contains the
# subproject nor climbs out, so the top is read again as "sub/up", which
# reads "sub/up/sub", which reads "sub/up/sub/up" and on until the path
# no longer resolves.  What comes out is a complaint about there being
# no build system for a path dozens of directories deep, naming a line
# in a Configfile that doesn't exist.  The line to name is the one in
# sub/Configfile.
mkdir sub
ln -s .. sub/up

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
SUBPROJECTS += up
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out | cut -c1-300

grep -q "[^/]sub/Configfile:1 'SUBPROJECTS += up'\|^sub/Configfile:1 'SUBPROJECTS += up'" out
grep -q "can't point at a directory that contains it" out
if grep -q "sub/up/sub/up" out
then
    exit 1
fi
test ! -e Makefile

exit 0
