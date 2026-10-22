#include "harness_start.bash"

# A subproject's make variable is its directory with every run of
# punctuation squeezed down to an underscore, so "lib-a" and "lib_a"
# -- two ordinary, different directory names -- both come out as
# pconfigure_subdir_lib_a.  Two projects sharing that variable would
# each find the other's directory through it, so the pair has to be
# refused; what this is about is that the refusal says where.  It has
# to name both SUBPROJECTS lines, since either of them is the one
# somebody might want to change, and it has to stop before a Makefile
# that one of them would build wrong gets written.
mkdir -p src lib-a/src lib_a/src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > lib-a/src/dash.c
echo 'int main(void) { return 0; }' > lib_a/src/under.c

cat >Configfile <<EOF
SUBPROJECTS += lib-a
SUBPROJECTS += lib_a

LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

cat >lib-a/Configfile <<EOF
LANGUAGES += c
BINARIES  += dash
SOURCES   += dash.c
EOF

cat >lib_a/Configfile <<EOF
LANGUAGES += c
BINARIES  += under
SOURCES   += under.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

head -n1 out | grep -q "Configfile:2 'SUBPROJECTS += lib_a'"
grep -q "error:.*pconfigure_subdir_lib_a" out
grep -q "Configfile:1 'SUBPROJECTS += lib-a'" out
grep -q "rename" out
test ! -e Makefile
