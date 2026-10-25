#include "harness_start.bash"

# A NUL byte has no business in a Configfile, and the only way one
# gets there is a file that isn't the text it looks like: a bad paste,
# a binary concatenated on, an editor that saved the wrong encoding.
# The line used to be cut off at the NUL without a word, so everything
# after it -- here the second define -- silently stopped being part of
# the build.  It has to be refused, naming the line.
mkdir -p src
cat >src/main.c <<'EOF'
#ifndef SECOND
#error everything after the NUL went missing
#endif
int main(void) { return 0; }
EOF

printf 'LANGUAGES   += c\nBINARIES    += main\nCOMPILEOPTS += -DFIRST\000 -DSECOND\nSOURCES     += main.c\n' \
    > Configfile
od -c Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:3" out
test ! -e Makefile
