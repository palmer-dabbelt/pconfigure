#include "harness_start.bash"

# The other way round: a SUBPROJECTS line taken out.  The Makefile the
# subproject had is still on disk, but the reconfigure writes a top
# Makefile that no longer includes it -- and no longer watches its
# Configfile, so editing that afterwards is not a reason to configure
# the tree again.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src sub/src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/sub.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/subbin

# Both lines the removal has to take out are checked for first, so the
# greps after the edit are known to be looking for something real.
grep -q '^include \$(pconfigure_subdir_sub)obj/Makefile.sub$' Makefile
grep -q ' \$(wildcard sub/Configfile)' Makefile

sleep 1
sed -i '/^SUBPROJECTS/d' Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
if grep -q '^include \$(pconfigure_subdir_sub)obj/Makefile.sub$' Makefile
then
    exit 1
fi
if grep -q ' \$(wildcard sub/Configfile)' Makefile
then
    exit 1
fi

sleep 1
echo "# edited" >> sub/Configfile
make $MAKE_ARGS > third.log 2>&1
cat third.log
# Make prints "Nothing to be done" after a reconfigure too, so the
# check that the edit went unwatched is that pconfigure didn't run.
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi
grep -q "Nothing to be done" third.log

exit 0
