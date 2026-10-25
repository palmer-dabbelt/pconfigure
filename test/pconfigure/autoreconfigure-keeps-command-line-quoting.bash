#include "harness_start.bash"

# The options pconfigure was run with are written into the Makefile so
# that the reconfigure make sets off can give them back.  On their way
# there they pass through two languages: make reads the variable,
# where a '#' starts a comment and a '$' starts a reference, and the
# shell then reads the recipe, where a space splits a word and a
# quote opens a string.  An option that comes back as something other
# than what was typed is a reconfigure that was not asked for.
#
# "--ppkg-config" is the option that carries the awkward name because
# it is the one that can: it is only read by a Configfile that runs
# ppkg-config, and this one doesn't, so nothing else in the build
# has to cope with the name for the round trip to be checked.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src Configfiles

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

cat >Configfiles/extra <<'EOF'
LANGUAGES       += c
BINARIES        += extra
SOURCES         += extra.c
EOF

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/extra.c

odd="it's \$HOME #1 \"\\\`x\` a\\#b \\\\#c"
$PTEST_BINARY $PCONFIGURE_ARGS --ppkg-config "$odd" --config extra
make $MAKE_ARGS
test -x bin/extra

sleep 1
echo "# a comment" >> Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
grep -q '^bin/extra:' Makefile

# And make, asked what it would run, hands the shell every option as
# the one word it was given as, with nothing in it expanded.
make $MAKE_ARGS -s -f - print <<'EOF'
include Makefile
.PHONY: print
print:
	@printf '%s\n' $(PCONFIGURE_ARGS) > args
EOF
printf '%s\n' --ppkg-config "$odd" --config extra > expected
cat args
cmp args expected

exit 0
