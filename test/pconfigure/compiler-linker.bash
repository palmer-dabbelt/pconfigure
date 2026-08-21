#include "harness_start.bash"

mkdir -p src badop/src

# A CROSS_COMPILE says who a target is being built for and leaves the
# language to work out a program name from that.  COMPILER and LINKER
# are the other half of it: they say what to run outright, which is
# what's left when a toolchain isn't named the way toolchains usually
# are, or when the compiler is a wrapper script somebody wrote because
# theirs needs an argument no Configfile has a word for.
#
# Both were in the manual for years while the parser aborted with
# "Command COMPILER not implemented" the moment it read one, so most
# of what's here is about where they land.  They're scoped exactly
# like COMPILEOPTS, which means three different places depending on
# what pconfigure is in the middle of, and this Configfile writes one
# at each of them.
cat >Configfile <<EOF
LANGUAGES += c
COMPILER   = ./mycc
LINKER     = ./myld

BINARIES  += lang
SOURCES   += shared.c
SOURCES   += lang.c

BINARIES  += targeted
COMPILER   = ./targetcc
SOURCES   += shared.c
SOURCES   += targeted.c

BINARIES  += sourced
SOURCES   += shared.c
COMPILER   = ./srccc
SOURCES   += sourced.c

BINARIES  += crossed
CROSS_COMPILE = nonexistent-elf-
COMPILER   = ./mycc
LINKER     = ./myld
SOURCES   += crossed.c

BINARIES  += ldone
LINKER     = ./myld1
SOURCES   += ldshared.c
SOURCES   += ldone.c

BINARIES  += ldtwo
LINKER     = ./myld2
SOURCES   += ldshared.c
SOURCES   += ldtwo.c
EOF

# The programs a COMPILER names have to actually run, or all this
# proves is that a string made it into a Makefile.  They're scripts
# written right here rather than a real alternate toolchain because a
# test can't ask for one to be installed, and each of them leaves its
# name behind so the build can be asked afterwards which ones really
# got run.
for wrapper in mycc targetcc srccc myld myld1 myld2
do
    cat >$wrapper <<'EOF'
#!/bin/bash
echo "$(basename $0)" >> $(dirname $0)/ran.log
exec cc "$@"
EOF
    chmod +x $wrapper
done

cat >src/shared.c <<EOF
int shared(void) { return 7; }
EOF

cat >src/lang.c <<EOF
int shared(void);
int main(void) { return shared() - 7; }
EOF

cat >src/targeted.c <<EOF
int shared(void);
int main(void) { return shared() - 7; }
EOF

cat >src/sourced.c <<EOF
int shared(void);
int main(void) { return shared() - 7; }
EOF

cat >src/crossed.c <<EOF
int main(void) { return 0; }
EOF

cat >src/ldshared.c <<EOF
int ldshared(void) { return 11; }
EOF

cat >src/ldone.c <<EOF
int ldshared(void);
int main(void) { return ldshared() - 11; }
EOF

cat >src/ldtwo.c <<EOF
int ldshared(void);
int main(void) { return ldshared() - 11; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Scoping                                                                    #
##############################################################################
# A COMPILER written after a LANGUAGES line belongs to the language,
# so it reaches every source built with it -- including the ones that
# were never mentioned in the same breath as a compiler.
grep -q "\./mycc .* -c src/lang\.c -o " Makefile
grep -q "\./mycc .* -c src/shared\.c -o " Makefile

# ... one written after a BINARIES line belongs to that binary, and
# beats what the language was told.  Both of that binary's sources
# get it, the one it shares with somebody else included.
grep -q "\./targetcc .* -c src/targeted\.c -o " Makefile
grep -q "\./targetcc .* -c src/shared\.c -o " Makefile
if grep -q "\./mycc .* -c src/targeted\.c -o " Makefile
then
    exit 1
fi

# ... and one written after a SOURCES line belongs to that file
# alone.  The other source of the same binary is still the language's
# business, which is the whole difference between this scope and the
# one above it.
grep -q "\./srccc .* -c src/shared\.c -o " Makefile
grep -q "\./mycc .* -c src/sourced\.c -o " Makefile
if grep -q "\./srccc .* -c src/sourced\.c -o " Makefile
then
    exit 1
fi

# LINKER scopes the same three ways, and the link line is the only
# place it shows up: a program that links is not thereby a program
# that compiles.
grep -q "\./myld -oobj/bin/lang/[0-9]*/local" Makefile
grep -q "\./myld -oobj/bin/lang/[0-9]*/install" Makefile
grep -q "\./myld1 -oobj/bin/ldone/[0-9]*/local" Makefile
grep -q "\./myld2 -oobj/bin/ldtwo/[0-9]*/local" Makefile
if grep -q "\./myld1 .* -c src/" Makefile
then
    exit 1
fi
if grep -q "\./myld -oobj/bin/ldone/" Makefile
then
    exit 1
fi

# ... and neither of them is anybody's compiler by accident: the
# language's COMPILER is what compiled the sources of a binary that
# only overrode the LINKER.
grep -q "\./mycc .* -c src/ldshared\.c -o " Makefile
grep -q "\./mycc .* -c src/ldone\.c -o " Makefile

##############################################################################
# Against a CROSS_COMPILE                                                    #
##############################################################################
# These two say overlapping things, so the order matters.  A
# CROSS_COMPILE only gets as far as handing the language a prefix to
# build a program name out of, and naming a program outright is a
# later and more specific answer to the same question -- so COMPILER
# wins, and "nonexistent-elf-gcc" is never asked for.  A build that
# got this backwards would fail on a toolchain that isn't installed
# while the Configfile plainly said what to run.
grep -q "\./mycc .* -c src/crossed\.c -o " Makefile
grep -q "\./myld -oobj/bin/crossed/[0-9]*/local" Makefile
if grep -q "nonexistent-elf-" Makefile
then
    exit 1
fi

##############################################################################
# The object cache                                                           #
##############################################################################
# An object is named after everything that went into building it, and
# the name of the compiler is one of those things.  shared.c is built
# three times here -- once by the language's compiler, once by a
# binary's, once by a source's -- and each of those has to land on a
# path of its own.
#
# Without the compiler in that hash all three would be the same file,
# and whichever target make happened to reach first would leave an
# object behind that the other two would silently link: a binary built
# by a compiler its Configfile never named, and no error anywhere.
grep -o "^obj/src/shared\.c/[0-9]*-static\.o:" Makefile | sort -u > shared.objs
cat shared.objs
test $(wc -l < shared.objs) -eq 3

# A LINKER, on the other hand, has nothing to do with how an object
# was made, so it must not fork that cache.  ldone and ldtwo share
# ldshared.c and differ in nothing but the program that links them,
# and they compile it exactly once between them -- forking here would
# be doubling the build for no reason at all.
grep -o "^obj/src/ldshared\.c/[0-9]*-static\.o:" Makefile | sort -u > ldshared.objs
cat ldshared.objs
test $(wc -l < ldshared.objs) -eq 1

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# The object cache is a claim about files on a disk, so count them
# there too rather than trusting the Makefile that asked for them.
test $(ls obj/src/shared.c/*-static.o | wc -l) -eq 3
test $(ls obj/src/ldshared.c/*-static.o | wc -l) -eq 1

# Every wrapper really was executed.  This is the assertion that
# separates "pconfigure wrote the name down" from "the build ran the
# program", which is the part anybody reaching for a COMPILER cares
# about.
for wrapper in mycc targetcc srccc myld myld1 myld2
do
    grep -q "^$wrapper\$" ran.log
done

# ... and what came out the far end is a working program, so the
# replacement compiler was handed a command line it could actually
# use.  Each of these returns non-zero unless it linked the object
# that belongs to it.
./bin/lang
./bin/targeted
./bin/sourced
./bin/crossed
./bin/ldone
./bin/ldtwo

##############################################################################
# The operator                                                               #
##############################################################################
# There's only ever one compiler, so appending to it doesn't mean
# anything: COMPILER and LINKER take '=' the way a CROSS_COMPILE does
# rather than '+=' the way COMPILEOPTS does.  Writing the wrong one is
# a fatal error, because the alternative is a line that reads like it
# said something and didn't.
cat >badop/src/bad.c <<EOF
int main(void) { return 0; }
EOF

cat >badop/Configfile <<EOF
LANGUAGES += c
COMPILER  += ./mycc
BINARIES  += bad
SOURCES   += bad.c
EOF

cd badop

if $PTEST_BINARY $PCONFIGURE_ARGS 2>compiler.err
then
    exit 1
fi
grep -q "Command COMPILER only supports '='" compiler.err

cat >Configfile <<EOF
LANGUAGES += c
LINKER    += ./myld
BINARIES  += bad
SOURCES   += bad.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS 2>linker.err
then
    exit 1
fi
grep -q "Command LINKER only supports '='" linker.err

exit 0
