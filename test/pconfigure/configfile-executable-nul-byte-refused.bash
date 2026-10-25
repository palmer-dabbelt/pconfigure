#include "harness_start.bash"

# An executable Configfile's output is read line by line exactly like
# a file's, so a generator that prints a NUL -- a printf of a C string
# with a stray "\0" in it, say -- has the same problem a file does:
# the rest of the line used to vanish.  Here that turned a binary
# called "main-debug" into one called "main", with nothing said.  The
# line is refused instead.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
#!/bin/sh
echo 'LANGUAGES   += c'
printf 'BINARIES    += main\000-debug\n'
echo 'SOURCES     += main.c'
EOF
chmod +x Configfile
./Configfile | od -c

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:2" out
test ! -e Makefile
