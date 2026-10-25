#include "harness_start.bash"

# clang's "-isystem-after <dir>" puts a directory on the end of the
# system include search.  It is a flag of its own that only happens
# to start with "-isystem", so reading it as "-isystem" with "-after"
# stuck on hands the compiler a made-up include directory called
# "-after" and the real directory as a file to compile -- at the top
# of the tree too, where nothing needs rerooting at all.
#
# gcc doesn't know the flag, so this only looks at what pconfigure
# writes rather than running the compiler: the flag has to come out
# whole, with its directory as the word after it, rerooted at the
# subproject that wrote it the same way "-isystem inc" is.  The
# header in that directory has to be found too, which is what makes
# it a prerequisite of the object.

mkdir -p src a/src a/inc

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += top
COMPILEOPTS += -isystem-after /usr/include
SOURCES     += top.c

SUBPROJECTS += a
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -isystem-after inc
SOURCES     += main.c
EOF

cat >a/inc/answer.h <<'EOF'
#define ANSWER 42
EOF

cat >a/src/main.c <<'EOF'
#include "answer.h"
int main(void) { return ANSWER - 42; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/obj/Makefile.a

# Nowhere is the flag cut in two.
if grep -e '-isystem -after' -e '-isystem a/-after' -e '-isystem $(pconfigure_subdir_a)-after' Makefile a/obj/Makefile.a
then
    exit 1
fi

# At the top it is left exactly as it was written...
grep -F -e '-isystem-after /usr/include' Makefile

# ... and in the subproject its directory is the subproject's own.
grep -F -e '-isystem-after $(pconfigure_subdir_a)inc' a/obj/Makefile.a

# The header in that directory was found, so editing it rebuilds the
# object.
grep -F -e 'src/main.c $(pconfigure_subdir_a)inc/answer.h' a/obj/Makefile.a
