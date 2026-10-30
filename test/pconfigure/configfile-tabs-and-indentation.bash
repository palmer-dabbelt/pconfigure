#include "harness_start.bash"

# How a line is laid out is up to whoever wrote it: tabs or spaces to
# line up the operators, indentation under the target a line belongs
# to, a stray space after the value.  All of it is whitespace between
# words and none of it is part of a command or a value.
mkdir -p src
cat >src/main.c <<'EOF'
#if !defined(ONE) || !defined(TWO)
#error a COMPILEOPTS written with odd whitespace went missing
#endif
int main(void) { return 0; }
EOF

printf 'LANGUAGES\t+=\tc\n' > Configfile
printf '\n' >> Configfile
printf 'BINARIES\t\t+=   main   \n' >> Configfile
printf '\tCOMPILEOPTS\t+=\t-DONE\t-DTWO\t\n' >> Configfile
printf '    SOURCES += \t main.c \t \n' >> Configfile
cat -ev Configfile

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out

# Nothing here names a file with whitespace in it, so there's nothing
# to warn about.
if grep -q "space in its name" out
then
    exit 1
fi
grep -q -- "-DONE -DTWO" Makefile

make $MAKE_ARGS
./bin/main
