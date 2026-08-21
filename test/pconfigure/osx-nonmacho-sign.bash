test "$(uname -s)" != "Darwin" && exit 0
#include "harness_start.bash"

top=$(pwd)
mkdir -p src

# macOS kills a process whose code signature doesn't check out rather
# than telling it anything, so pconfigure signs what it links: an
# ad-hoc "codesign --force --sign -" is appended to every link
# command, carrying whatever ENTITLEMENTS asked for.
#
# A signature is a Mach-O idea, though, and the linker on the far end
# of a link isn't always one that makes Mach-Os.  Point a
# CROSS_COMPILE at a toolchain for somebody else's machine, or hand a
# LINKER a wrapper that does, and what lands in obj/ is an ELF.
#
# codesign doesn't refuse those, which is the whole problem -- it
# signs them "Format=generic", hangs a CodeDirectory off the file in
# an extended attribute that means nothing to the machine the thing is
# going to run on, accepts --entitlements while ignoring it, and fails
# outright on a file that arrived wearing attributes of its own.  Any
# of that is worse than not signing: at best it's a lie about a file
# this machine was never going to run, at worst it's a build that
# stops.
#
# So the link asks what it actually produced before signing it.  This
# file is about that question getting asked, and about the answer for
# a real Mach-O being exactly what it was before.
cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += signed
ENTITLEMENTS  = signed.plist
SOURCES      += signed.c

BINARIES     += plain
SOURCES      += plain.c
EOF

cat >signed.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.hypervisor</key>
	<true/>
</dict>
</plist>
EOF

cat >src/signed.c <<EOF
int main(void) { return 0; }
EOF

cat >src/plain.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The guard is on the sign, not on the link, so it has to be wherever
# a sign is.  That's four places for two binaries: each of them is
# linked twice, once for the build tree and once for the copy that
# gets installed, and the installed one is a link of its own rather
# than a copy of the local one -- it would go out the door unguarded
# if only the local link had been fixed.
for target in signed plain
do
    grep -q "case \$\$(/usr/bin/file -b obj/bin/$target/[0-9]*/local) in Mach-O[*])" Makefile
    grep -q "case \$\$(/usr/bin/file -b obj/bin/$target/[0-9]*/install) in Mach-O[*])" Makefile
done

# Nothing signs outside a guard.  Counting rather than eyeballing is
# the point here: a fifth codesign appearing somewhere later with no
# "file -b" in front of it is exactly the bug, and it wouldn't show up
# in any of the greps above.
test "$(grep -c codesign Makefile)" = "4"
test "$(grep -c '/usr/bin/file -b' Makefile)" = "4"
grep -c "in Mach-O[*])" Makefile > guards.count
test "$(cat guards.count)" = "4"

# ... and none of it landed on a compile.  An object file is a Mach-O
# too, so a guard that had drifted onto a compile recipe would sign
# every .o in the build and still pass every assertion above it.
if grep -- "-c src/" Makefile | grep -q "codesign"
then
    exit 1
fi
if grep -- "-c src/" Makefile | grep -q "/usr/bin/file -b"
then
    exit 1
fi

# What the guard is wrapped around is the same command it was wrapped
# around before it grew a guard.  The entitlements in particular have
# to stay on the codesign line itself: signing without them doesn't
# leave a binary's previous entitlements alone, it drops them, so a
# --entitlements that ended up on some other line would read fine and
# mean nothing.
grep -q "in Mach-O[*]).*codesign .*--entitlements signed.plist.* obj/bin/signed/[0-9]*/local" Makefile
grep -q "in Mach-O[*]).*codesign .*--entitlements signed.plist.* obj/bin/signed/[0-9]*/install" Makefile

# ... and a binary that asked for none still gets none.  The guard
# rewrote every sign command in the file, including this one, and the
# thing it must not have done is hand somebody else's plist to a
# binary whose Configfile never mentioned one.
if grep -q "codesign .*--entitlements.* obj/bin/plain/" Makefile
then
    exit 1
fi

##############################################################################
# The Mach-O half                                                            #
##############################################################################
make $MAKE_ARGS

# A signature that doesn't check out gets the process SIGKILLed rather
# than anything as polite as an error, so verify it and then run the
# thing.  This is the assertion the guard could most easily have
# broken: a "case" that never matched would leave every binary in the
# tree unsigned, and unsigned is the one state macOS won't exec.
codesign --verify bin/signed
./bin/signed
codesign --verify bin/plain
./bin/plain

# The entitlements are read back out of the binary rather than off the
# command line that made it, because a codesign that quietly drops
# them still reports success.  Under a guard there's a second way to
# lose them -- the sign not running at all -- and this catches both.
codesign -d --entitlements - --xml bin/signed 2>/dev/null > signed.ents
grep -q "com.apple.security.hypervisor" signed.ents

codesign -d --entitlements - --xml bin/plain 2>/dev/null > plain.ents
if grep -q "com.apple.security.hypervisor" plain.ents
then
    exit 1
fi

##############################################################################
# A linker that doesn't make Mach-Os                                         #
##############################################################################
# Standing in for a cross toolchain.  It has to be a script rather
# than a real one because a test can't ask for somebody else's
# toolchain to be installed, and it has to be one program rather than
# a separate compiler and linker because that's how the toolchains
# this is about are shaped: one driver that both compiles and links.
#
# The compile is passed straight through to the real cc, since the
# objects only have to be something the "linker" can be handed.  The
# link ignores them and writes a 64-byte AArch64 ELF header, which is
# all file(1) reads to name what a file is.
#
# Note the "-o" handling: pconfigure glues the output path onto the
# flag on a link line ("-oobj/bin/x/1234/local") and separates them on
# a compile line ("-o obj/..."), so a stub that only understood one
# spelling would write its ELF to a file called "" and the build would
# fail for a reason that has nothing to do with signing.
cat >stub.sh <<'EOF'
#!/bin/bash
out=""
compile=false
for arg in "$@"
do
    case "$arg" in
    -c)  compile=true;;
    -o)  ;;
    -o*) out="${arg#-o}";;
    esac
done

if $compile
then
    exec cc "$@"
fi

test -n "$out"
mkdir -p $(dirname $out)
printf '\177ELF\002\001\001\000\000\000\000\000\000\000\000\000\002\000\267\000\001\000\000\000' > $out
dd if=/dev/zero bs=1 count=40 >> $out 2>/dev/null
chmod +x $out
EOF
chmod +x stub.sh

mkdir -p elf/src
cd elf

# Same two shapes as above -- one binary naming entitlements and one
# not -- because --entitlements is the argument codesign takes and
# then ignores on a file that isn't a Mach-O, and a project that had
# asked for an entitlement and silently not got one is the worst way
# for this to go.
cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += foreign
SOURCES      += foreign.c

BINARIES     += foreignent
ENTITLEMENTS  = foreign.plist
SOURCES      += foreignent.c
EOF

cat >foreign.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.hypervisor</key>
	<true/>
</dict>
</plist>
EOF

cat >src/foreign.c <<EOF
int main(void) { return 0; }
EOF

cat >src/foreignent.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The Makefile still says to sign both of these -- the guard is a
# runtime question about a file that doesn't exist yet, not something
# configure could have decided.  Worth pinning down, because it's what
# makes the assertions below a statement about the guard rather than
# about pconfigure having quietly stopped emitting codesign at all.
grep -q "codesign .* obj/bin/foreign/[0-9]*/local" Makefile
grep -q "codesign .*--entitlements foreign.plist.* obj/bin/foreignent/[0-9]*/local" Makefile

# The build has to survive, which is half of what was wrong: codesign
# doesn't merely mislabel a foreign object, it fails outright on one
# carrying attributes its own linker left behind, and a link recipe
# that fails is a build that stops.  So capture the output and go
# looking for the link, rather than trusting that make said nothing.
make $MAKE_ARGS CC=$top/stub.sh > build.out
cat build.out
grep -q "^LD.*foreign\$" build.out
grep -q "^LD.*foreignent\$" build.out

for bin in foreign foreignent
do
    test -x bin/$bin

    # What the stub actually produced, asked the same way the guard
    # asks it.  If this isn't an ELF then the rest of the loop is
    # asserting nothing.
    /usr/bin/file -b bin/$bin > $bin.type
    cat $bin.type
    grep -q "^ELF" $bin.type

    # ... and it came out the way its own linker left it.  These are
    # two separate questions on purpose: "not signed at all" is
    # codesign's own reading of the file, and the extended attribute
    # is where a generic signature physically lives, so the second one
    # catches a signature that got written somewhere codesign has
    # since stopped looking.
    if codesign -dv bin/$bin 2>/dev/null
    then
        exit 1
    fi
    if xattr -p com.apple.cs.CodeDirectory bin/$bin 2>/dev/null
    then
        exit 1
    fi
done

# Neither of those two assertions means anything unless codesign
# would have gone through with it, so make it go through with it on a
# copy.  This is the bug, reproduced: a file this machine cannot
# execute and never will, wearing an ad-hoc signature, with a
# --entitlements that was accepted and dropped on the floor.
cp bin/foreignent oops
codesign --force --sign - --entitlements foreign.plist oops
codesign -dv oops 2>/dev/null
xattr -p com.apple.cs.CodeDirectory oops > oops.xattr
test -s oops.xattr

cd $top

##############################################################################
# The way this happens for real: CROSS_COMPILE                               #
##############################################################################
# Nobody sets out to link an ELF on a Mac.  What they do is name a
# toolchain for the machine the program is going to run on, and then
# every link in the project quietly stops producing Mach-Os.  The
# section above drove that with a CC on the make command line, which
# proves the guard works; this one drives it the way a Configfile
# would, which is the case somebody actually hit.
mkdir -p cross/src cross/tc
cp stub.sh cross/tc/faketc-gcc
cd cross

cat >Configfile <<EOF
LANGUAGES     += c
CROSS_COMPILE  = faketc-

BINARIES      += crossed
SOURCES       += crossed.c
EOF

cat >src/crossed.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The prefix reached both halves of the toolchain, so the thing doing
# the linking really is the foreign one.
grep -q "faketc-gcc .* -c src/crossed.c -o " Makefile
grep -q "faketc-gcc .* -oobj/bin/crossed/[0-9]*/local" Makefile

# And here the guard isn't needed, because there's nothing to guard:
# a CROSS_COMPILE has already said this link is for another machine,
# so no signature is asked for in the first place.  Where the section
# above catches an ELF that turned up unannounced, this one never
# writes the codesign down at all.
if grep -q "codesign" Makefile
then
    exit 1
fi
if grep -q "/usr/bin/file -b" Makefile
then
    exit 1
fi

# The same knowledge, applied to the link line itself.  These are the
# flags that only Apple's linker understands, and they are the other
# half of the same bug: "@loader_path" is a literal string that means
# nothing on the machine this binary is going to run on, and
# "-install_name" is not an option GNU ld has at all -- a
# cross-compiled shared library would stop dead on it.
if grep -q "loader_path" Makefile
then
    exit 1
fi
if grep -q "install_name" Makefile
then
    exit 1
fi

# ... and what it uses instead is the spelling ELF has always had.
grep -q 'rpath,\\[$][$]ORIGIN/' Makefile

# The toolchain is found on the PATH, the way a CROSS_COMPILE expects
# to find one, and only for this build.
env PATH="$(pwd)/tc:$PATH" make $MAKE_ARGS > build.out
cat build.out
grep -q "^LD.*crossed\$" build.out

test -x bin/crossed
/usr/bin/file -b bin/crossed > crossed.type
cat crossed.type
grep -q "^ELF" crossed.type

if codesign -dv bin/crossed 2>/dev/null
then
    exit 1
fi
if xattr -p com.apple.cs.CodeDirectory bin/crossed 2>/dev/null
then
    exit 1
fi

exit 0
