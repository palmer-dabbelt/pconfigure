#include "harness_start.bash"

# Before a GENERATE's script is run pconfigure makes the directory its
# output goes in, and when that can't be done the error has to name the
# GENERATE line and say what the directory is for, like every other way
# of running the script that fails.  A regular file sitting where the
# directory should be makes "mkdir -p" fail the same way whoever runs
# the test, root included, which a directory without its write bit
# would not.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<'EOF'
  #include "gen.h"
int main(void) { return 0; }
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     ;;
--generate) echo "int x;" ;;
esac
EOF
chmod +x src/gen.h.proc

mkdir -p obj
touch obj/proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3 'GENERATE += gen.h'$" configure.out
grep -q "error: 'mkdir -p obj/proc' exited with status 1$" configure.out
grep -q "obj/proc is where gen.h gets generated" configure.out
if grep -q "system(" configure.out
then
    exit 1
fi

exit 0
