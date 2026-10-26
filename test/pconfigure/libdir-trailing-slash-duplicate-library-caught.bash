#include "harness_start.bash"

# Two libraries that land on one file are one target: if their rules
# differ, pconfigure stops with "Mismatched recipe".  The warning that
# comes before that compares normalized paths, but the rules don't: a
# library under "LIBDIR = lib/" is the make target "lib//libf.so", a
# different name from "lib/libf.so" for the same file.  So the warning
# said the two were one target, pconfigure carried on, and "make" ran
# both rules into "lib/libf.so.tmp" and failed on "mv: cannot stat".
mkdir -p src
echo 'int f(void) { return 3; }' > src/f.c
echo 'int f(void) { return 4; }' > src/g.c

cat >Configfile <<'EOF2'
LANGUAGES += c

LIBRARIES += libf.so
SOURCES   += f.c

LIBDIR     = lib/
LIBRARIES += libf.so
SOURCES   += g.c
EOF2

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2> stderr
status="$?"
set -e
cat stderr

# Two libraries asking for different contents in one file have no
# correct build, so this is the configure-time error the same two
# lines get without the slash.  Let through, a serial make happens to
# finish, which is worse: it installs whichever came last and says
# nothing about the other.
test "$status" != 0
grep -F "Mismatched recipe" stderr
