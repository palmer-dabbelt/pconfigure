#include "harness_start.bash"

# A staging directory with a parenthesis in its name -- "stage (copy)"
# is what a file manager calls a duplicated directory, and the space
# is already refused, so "stage(copy)" is what is left.  $(DESTDIR)
# reaches the install recipes as a bare word, where the shell reads a
# '(' as the start of a subshell and stops the whole recipe with a
# syntax error about generated text.  The Makefile already answers a
# DESTDIR with a ':', ';' or '%' with a sentence naming DESTDIR; this
# needs either that, or an install that lands where it was told.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF2

echo 'int main(void) { return 0; }' > src/hello.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

destdir="$tempdir/stage(copy)"
if make $MAKE_ARGS install DESTDIR="$destdir" > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/hello"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
    test ! -e "$destdir"
fi

exit 0
