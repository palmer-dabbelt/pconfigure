#include "harness_start.bash"

# One subproject links a program and another has it as a CONFIG_DEPS,
# which makes the program a prerequisite of a makefile make includes:
# make builds it while it is remaking those, before it has read what
# they say.  Under AUTORECONFIGURE the objects a link is made of are
# only ever said by the fragments pdeps writes, and a change of
# options renames every one of them.  So the first make after the
# change found the fragment missing, wrote it, and linked the program
# on the way to the other subproject's makefile anyway -- out of no
# objects at all, "undefined reference to `main'" -- and only the make
# after that got it right.  One make has to do it.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p tool/src user

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += tool
SUBPROJECTS     += user
EOF

cat >tool/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += tool
SOURCES         += tool.c
EOF

cat >user/Configfile <<'EOF'
CONFIG_DEPS     += ../tool/bin/tool
EOF

echo 'int main(void) { return 0; }' > tool/src/tool.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS
test -x tool/bin/tool

sleep 1
sed -i 's/^SOURCES.*/&\nCOMPILEOPTS     += -DRENAMED/' tool/Configfile
cat tool/Configfile

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
tool/bin/tool

exit 0
