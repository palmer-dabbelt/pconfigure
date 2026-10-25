#include "harness_start.bash"

# Configfiles/main as a directory -- somebody meant Configfiles/ to
# hold their files and made one too many levels -- passes the
# "executable" test every directory passes, so pconfigure used to try
# to run it: the shell said "Is a directory", nothing was printed, and
# an empty Makefile was written with the real Configfile lines sitting
# unread one level down.  This expects the run to stop and say that
# the file is a directory.
mkdir -p src Configfiles/main
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/main/Configfile <<'END'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfiles/main" out
grep -q "is a directory" out
