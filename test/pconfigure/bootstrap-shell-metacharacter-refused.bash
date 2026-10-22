#include "harness_start.bash"

# What a BOOTSTRAP names is written into the generated Makefile as
# text -- as PCONFIGURE_SRCPATH and in the recipes that build and
# distclean the vendored tree -- which is exactly the road every
# other path-taking command refuses a shell metacharacter on.  A
# directory really can be called "p(c)", and a shell reads that
# parenthesis as the start of a subshell wherever it sits, so the
# line has to be refused as written rather than handed to a recipe.
mkdir -p src 'vendor/p(c)/src'

cat >'vendor/p(c)/Configfile' <<EOF
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF
echo 'exit 0' > 'vendor/p(c)/src/pconfigure.bash'
printf '#!/bin/bash\nexit 0\n' > 'vendor/p(c)/bootstrap.sh'
chmod +x 'vendor/p(c)/bootstrap.sh'

cat >Configfile <<EOF
BOOTSTRAP  = vendor/p(c)

LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep "PCONFIGURE_SRCPATH" Makefile || true
    exit 1
fi
cat out
grep -q "BOOTSTRAP has a '(' in it" out
grep -q "Configfile:1" out
test ! -e Makefile

exit 0
