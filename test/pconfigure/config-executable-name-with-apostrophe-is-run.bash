#include "harness_start.bash"

# The same shell command as config-executable-name-with-space-is-run,
# with an apostrophe in the name: unquoted, the shell saw an
# unterminated quote, printed a syntax error, and the CONFIG's lines
# were never read.  An apostrophe is also the one character a
# single-quoted shell word can't hold as it is, so this is the name
# that shows the quoting is done properly rather than just wrapped.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/hello.c

cat >"Configfiles/palmer's" <<'EOF2'
LANGUAGES += c
BINARIES += hello
SOURCES  += hello.c
EOF2

# Read as a file, it works.
$PTEST_BINARY --config "palmer's"
grep -q '^bin/hello:' Makefile
rm -f Makefile

# The same lines printed by a program have to work the same.
cat >"Configfiles/palmer's" <<'EOF2'
#!/bin/sh
echo "LANGUAGES += c"
echo "BINARIES += hello"
echo "SOURCES  += hello.c"
EOF2
chmod +x "Configfiles/palmer's"
$PTEST_BINARY --config "palmer's" > out 2>&1 || { cat out; exit 1; }
cat out
grep -q '^bin/hello:' Makefile
