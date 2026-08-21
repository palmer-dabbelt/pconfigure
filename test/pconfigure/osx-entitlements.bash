test "$(uname -s)" != "Darwin" && exit 0
#include "harness_start.bash"

mkdir -p src

# Entitlements are the only way to ask the macOS kernel for something
# it doesn't hand out by default -- the hypervisor, in the case this
# was written for -- and the only way onto a binary is through its
# code signature.  pconfigure signs every Mach-O it links, so it's the
# one holding the pen.
cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += test
ENTITLEMENTS  = test.plist
SOURCES      += test.c

BINARIES     += plain
SOURCES      += plain.c

LIBRARIES    += libhv.so
ENTITLEMENTS  = test.plist
SOURCES      += hv.c
EOF

cat >test.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.hypervisor</key>
	<true/>
</dict>
</plist>
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

cat >src/plain.c <<EOF
int main(void) { return 0; }
EOF

cat >src/hv.c <<EOF
int hv(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The signature the binary ends up wearing is the one pconfigure
# applies, so that's where the entitlements have to be named.
grep -q "codesign .*--entitlements test.plist.* obj/bin/test/[0-9]*/local" Makefile
grep -q "codesign .*--entitlements test.plist.* obj/bin/test/[0-9]*/install" Makefile

# Changing what a binary is allowed to do has to re-sign it, which
# means the plist is a prerequisite of the link like any other input.
grep -q "^obj/bin/test/[0-9]*/local:.* test.plist" Makefile
grep -q "^obj/bin/test/[0-9]*/install:.* test.plist" Makefile

# A binary that didn't ask for any is still signed, just with nothing
# in it: the ad-hoc signature is what lets it run at all.
grep -q "codesign .*obj/bin/plain/[0-9]*/local" Makefile
if grep -q "codesign .*--entitlements.* obj/bin/plain/" Makefile
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
make $MAKE_ARGS

# What all of this was for.  Note that this reads the signature back
# out of the binary rather than trusting the command line that made
# it, because dropping the entitlements was something codesign did
# quietly while reporting success.
codesign -d --entitlements - --xml bin/test 2>/dev/null > test.ents
grep -q "com.apple.security.hypervisor" test.ents

# A signature that doesn't check out gets the process SIGKILLed rather
# than anything as polite as an error, so run the thing.
codesign --verify bin/test
./bin/test

# A library takes the option without complaint and comes out validly
# signed, which is as far as this goes: macOS only ever reads
# entitlements off the executable, so a dylib that names some is
# signed with nothing in it.  Worth pinning down, because codesign
# accepts the argument and says nothing about ignoring it.
codesign --verify lib/libhv.so
codesign -d --entitlements - --xml lib/libhv.so 2>/dev/null > hv.ents
if grep -q "com.apple.security.hypervisor" hv.ents
then
    exit 1
fi

# Asking for nothing gets nothing: a binary with no ENTITLEMENTS isn't
# quietly handed somebody else's.
codesign --verify bin/plain
./bin/plain
codesign -d --entitlements - --xml bin/plain 2>/dev/null > plain.ents
if grep -q "com.apple.security.hypervisor" plain.ents
then
    exit 1
fi

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# Taking an entitlement away has to actually take it away, which it
# only does if the plist is watched.
sleep 2s
cat >test.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
</dict>
</plist>
EOF
make $MAKE_ARGS

codesign -d --entitlements - --xml bin/test 2>/dev/null > second.ents
grep -q "com.apple.security.cs.allow-jit" second.ents
if grep -q "com.apple.security.hypervisor" second.ents
then
    exit 1
fi
./bin/test

##############################################################################
# Installing                                                                 #
##############################################################################
# An installed binary is a copy of a different link than the local
# one, so it gets signed on its own and has to come out the same way.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install install

codesign --verify $(pwd)/install/usr/local/bin/test
codesign -d --entitlements - --xml $(pwd)/install/usr/local/bin/test \
    2>/dev/null > install.ents
grep -q "com.apple.security.cs.allow-jit" install.ents

exit 0
