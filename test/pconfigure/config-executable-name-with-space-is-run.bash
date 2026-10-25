#include "harness_start.bash"

# An executable CONFIG is run through a shell, from the directory it
# lives in, and its name is one word of that shell command.  A name
# with a space in it is fine as a plain file, so the same file made
# executable has to be run as itself too: left unquoted, the shell ran
# "./Configfiles/my" with "conf" as its argument, the lines the program
# would have printed were never read, and the Makefile came out without
# the target they declared.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/hello.c

cat >"Configfiles/my conf" <<'EOF2'
LANGUAGES += c
BINARIES += hello
SOURCES  += hello.c
EOF2

# Read as a file, it works.
$PTEST_BINARY --config "my conf"
grep -q '^bin/hello:' Makefile
rm -f Makefile

# The same lines printed by a program have to work the same.
cat >"Configfiles/my conf" <<'EOF2'
#!/bin/sh
echo "LANGUAGES += c"
echo "BINARIES += hello"
echo "SOURCES  += hello.c"
EOF2
chmod +x "Configfiles/my conf"
$PTEST_BINARY --config "my conf" > out 2>&1 || { cat out; exit 1; }
cat out
grep -q '^bin/hello:' Makefile
