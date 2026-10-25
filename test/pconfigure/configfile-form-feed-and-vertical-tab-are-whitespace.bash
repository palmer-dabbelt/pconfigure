#include "harness_start.bash"

# Emacs users break long files into pages with a form feed on a line
# of its own, and a vertical tab is the other C white-space character
# nobody types on purpose.  Both are white space to a Configfile: a
# line holding only one is blank, and one between words is just the
# gap between them.
mkdir -p src
cat >src/main.c <<'EOF'
#if !defined(ONE) || !defined(TWO)
#error a define separated by a form feed or vertical tab went missing
#endif
int main(void) { return 0; }
EOF

printf 'LANGUAGES   += c\n\f\nBINARIES\v+=\fmain\n\v\nCOMPILEOPTS += -DONE\f-DTWO\nSOURCES     += main.c\f\n' \
    > Configfile
od -c Configfile

# Read as anything but white space, the lone form feed would be an
# unknown command and the configure would stop; the ones inside lines
# would end up in the Makefile as part of a target's name or glued to
# a flag.  So the configure has to say nothing at all, and neither
# character may get as far as the Makefile.
$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out
test ! -s out
if grep -q $'[\f\v]' Makefile
then
    exit 1
fi
grep -q -- "-DONE -DTWO" Makefile
make $MAKE_ARGS
./bin/main
