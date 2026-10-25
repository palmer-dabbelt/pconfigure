#include "harness_start.bash"

# The C++ half of "make -R": "${CXX} -x c++ ..." with no built-in CXX
# is a recipe line starting with "-x", which make reads as "ignore
# errors", so an edit failed to compile, nothing relinked and make
# still exited 0.  C++ writes its recipes through a different language
# than C does, so C working says nothing about this one.  The static
# library is there for ${AR}, which -R takes away just the same.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c++

LIBRARIES += libanswer.a
SOURCES   += libanswer.c++

BINARIES  += answer
DEPLIBS   += answer
SOURCES   += answer.c++
EOF

cat >src/libanswer.c++ <<'EOF'
int answer() { return 1; }
EOF

cat >src/answer.c++ <<'EOF'
int answer();
int main() { return answer(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/answer
status="$?"
set -e
test "$status" = 1

sleep 1
cat >src/libanswer.c++ <<'EOF'
int answer() { return 2; }
EOF

make $MAKE_ARGS -R > make.out 2>&1 || { cat make.out; exit 1; }
cat make.out
if grep -q "(ignored)" make.out
then
    echo "make ignored a failed recipe under -R" >&2
    exit 1
fi

set +e
./bin/answer
status="$?"
set -e
test "$status" = 2
