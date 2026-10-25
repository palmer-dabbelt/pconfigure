#include "harness_start.bash"

# An executable Configfile is run from the --srcpath it lives under,
# by a shell command that cd's there first.  Left unquoted, a srcpath
# with an apostrophe in it was an unterminated quote to that shell, so
# the program was never run at all.  (A srcpath with whitespace is
# refused outright, since make can't name anything under it.)  This
# only asks whether the program ran, and ran where it was promised it
# would: it leaves a file behind in its own directory and prints
# nothing.
mkdir -p "my'src/Configfiles"

cat >"my'src/Configfiles/main" <<'EOF2'
#!/bin/sh
touch ran-here
EOF2
chmod +x "my'src/Configfiles/main"

$PTEST_BINARY --srcpath "my'src" > out 2>&1 || { cat out; exit 1; }
cat out
test -f "my'src/ran-here"
