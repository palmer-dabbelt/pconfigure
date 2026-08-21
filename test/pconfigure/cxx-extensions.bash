#include "harness_start.bash"

mkdir -p src

# Which of the half-dozen names C++ goes by a project picked is its own
# business, and none of them mean anything different.  ".cpp" and ".cc"
# used to be a hard configure error, which is a strange thing to tell
# somebody about the two most popular spellings there are.
#
# The one name that isn't C++'s is ".c", which belongs to C: keeping it
# out is the whole of what stops the two languages from both claiming
# the same file.
cat >Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += c++

BINARIES    += bcxxpp
SOURCES     += mcxxpp.c++

BINARIES    += bcpp
SOURCES     += mcpp.cpp

BINARIES    += bcxx
SOURCES     += mcxx.cxx

BINARIES    += bcc
SOURCES     += mcc.cc

BINARIES    += bcap
SOURCES     += mcap.C

BINARIES    += bc
SOURCES     += mc.c

BINARIES    += bhdr
SOURCES     += uses.c++

BINARIES    += bshared
SOURCES     += usesh.c
EOF

cat >src/mcxxpp.c++ <<'EOF'
int main(void) { return 0; }
EOF
cat >src/mcpp.cpp <<'EOF'
int main(void) { return 0; }
EOF
cat >src/mcxx.cxx <<'EOF'
int main(void) { return 0; }
EOF
cat >src/mcc.cc <<'EOF'
int main(void) { return 0; }
EOF

# ".C" is C++ too, and it's spelled out in a SOURCES line here rather
# than being reached for through a header.  Note that its stem is its
# own: this filesystem doesn't care about case, so an "mc.C" sitting
# next to the "mc.c" below would be the same file and there'd be
# nothing to test.
cat >src/mcap.C <<'EOF'
int main(void) { return 0; }
EOF

cat >src/mc.c <<'EOF'
int main(void) { return 0; }
EOF

# A header and the source that implements it are the same name with a
# different ending, and that's the only thing saying the two go
# together -- nobody writes it down.  So every spelling of the header
# end has to be tried against every spelling of the source end.
#
# The indentation on the include lines below is load-bearing: this
# file is fed through pbashc first, and pbashc eats a "#include" that
# starts a line no matter what quoting the heredoc around it had.
cat >src/uses.c++ <<'EOF'
  #include "phpp.hpp"
  #include "phh.hh"
  #include "phxx.hxx"
  #include "phplus.h++"
  #include "pplain.h"
int main(void) { return phpp() + phh() + phxx() + phplus() + pplain(); }
EOF

cat >src/phpp.hpp <<'EOF'
int phpp(void);
EOF
cat >src/phpp.cpp <<'EOF'
int phpp(void) { return 0; }
EOF

cat >src/phh.hh <<'EOF'
int phh(void);
EOF
cat >src/phh.cc <<'EOF'
int phh(void) { return 0; }
EOF

cat >src/phxx.hxx <<'EOF'
int phxx(void);
EOF
cat >src/phxx.cxx <<'EOF'
int phxx(void) { return 0; }
EOF

cat >src/phplus.h++ <<'EOF'
int phplus(void);
EOF
cat >src/phplus.c++ <<'EOF'
int phplus(void) { return 0; }
EOF

cat >src/pplain.h <<'EOF'
int pplain(void);
EOF
cat >src/pplain.cxx <<'EOF'
int pplain(void) { return 0; }
EOF

# The plainest arrangement there is, and the one that pins down what
# the header search deliberately doesn't do.  See below.
cat >src/usesh.c <<'EOF'
  #include "shared.h"
int main(void) { return shared(); }
EOF

cat >src/shared.h <<'EOF'
int shared(void);
EOF
cat >src/shared.c <<'EOF'
int shared(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS 2>configure.err
cat configure.err
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# Every spelling reached the C++ compiler, and the extension came
# through into the object's name verbatim rather than being trimmed
# off: two sources whose names differ only in how they say "C++" are
# two different files and have to end up as two different objects.
for src in mcxxpp.c++ mcpp.cpp mcxx.cxx mcc.cc mcap.C
do
    grep -q "^obj/src/$src/[0-9]*-static.o: src/$src\$" Makefile
    grep -A3 "^obj/src/$src/[0-9]*-static.o:" Makefile | grep -q -- '-x c++'
done

# ... and ".c" still went to C, which is the half of this that had to
# keep working.  Both halves are worth asserting: a ".c" that quietly
# started being compiled as C++ would still build most of the time,
# and then wouldn't.
grep -q "^obj/src/mc.c/[0-9]*-static.o: src/mc.c\$" Makefile
grep -A3 "^obj/src/mc.c/[0-9]*-static.o:" Makefile | grep -q -- '-x c '
if grep -A3 "^obj/src/mc.c/[0-9]*-static.o:" Makefile | grep -q -- '-x c++'
then
    exit 1
fi

# Nobody had to guess at any of that.  Two languages both claiming one
# file is a warning and then a coin flip, so the absence of the
# warning is the assertion that the extension lists don't overlap.
if grep -q "Multiple valid languages" configure.err
then
    exit 1
fi

# The source behind each header was found, through every spelling of
# the header's name -- including the bare ".h", which a C++ project is
# perfectly entitled to use.
grep -q "^obj/src/phpp.cpp/[0-9]*-static.o: src/phpp.cpp\$" Makefile
grep -q "^obj/src/phh.cc/[0-9]*-static.o: src/phh.cc\$" Makefile
grep -q "^obj/src/phxx.cxx/[0-9]*-static.o: src/phxx.cxx\$" Makefile
grep -q "^obj/src/phplus.c++/[0-9]*-static.o: src/phplus.c++\$" Makefile
grep -q "^obj/src/pplain.cxx/[0-9]*-static.o: src/pplain.cxx\$" Makefile

# ... and the header itself is watched, so editing it recompiles what
# included it.
grep -q "^obj/src/uses.c++/[0-9]*-static.o:.* src/phpp.hpp" Makefile
grep -q "^obj/src/uses.c++/[0-9]*-static.o:.* src/phplus.h++" Makefile

##############################################################################
# The one extension the header search won't guess                            #
##############################################################################
# ".C" is a C++ source everywhere else in this file, but the search
# that goes from a header to the source behind it leaves it out on
# purpose.  ".C" and ".c" differ only in case, and this filesystem
# doesn't care: given "shared.h", guessing both would find "shared.c"
# and "shared.C", which are one file wearing two names.  Both would be
# compiled, both would be handed to the linker, and the link would die
# on duplicate symbols -- for a project that did nothing more exotic
# than put a header next to its source.
#
# So "shared" is exactly one object, and nothing anywhere in the
# Makefile is spelled "shared.C".
test "$(grep -c "^obj/src/shared\.[cC]/[0-9]*-static.o:" Makefile)" = "1"
grep -q "^obj/src/shared.c/[0-9]*-static.o: src/shared.c\$" Makefile
if grep -q "shared\.C" Makefile
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
# The toolchain agreed with all of that, which is the part no amount
# of reading the Makefile proves: a Makefile that greps right and
# doesn't compile is worth nothing.
make $MAKE_ARGS

for bin in bcxxpp bcpp bcxx bcc bcap bc bhdr bshared
do
    test -x bin/$bin
    ./bin/$bin
done

# The objects landed where the Makefile said they would, extension and
# all.
test -d obj/src/mcpp.cpp
test -d obj/src/mcc.cc
test -d obj/src/mcap.C
test -d obj/src/mc.c

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# Touching a header found through one of the newly-accepted spellings
# rebuilds the thing that included it, which is the dependency edge
# the search exists to draw.
sleep 2s
touch src/phh.hh
make $MAKE_ARGS > second.out
grep -q "C++	uses.c++" second.out
./bin/bhdr

exit 0
