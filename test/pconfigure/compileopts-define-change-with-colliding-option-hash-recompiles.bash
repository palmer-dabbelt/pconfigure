#include "harness_start.bash"

# An object is named after a hash of its compile line, and that hash is
# the only thing that tells make a changed COMPILEOPTS is a different
# object: make never reruns a recipe because its text moved.  Two
# option lists that hash alike name one object, so switching from one
# to the other leaves the object built from the first exactly where it
# is.  The hash used to be folded into 32 bits, which is short enough
# that such a pair is easy to come by: the birthday bound puts one
# among a few tens of thousands of '-D' values.
#
# The pair is found here rather than written down because pconfigure
# hashes with the C++ library's std::hash, which is whatever the
# compiler pconfigure was built with says it is.  The search is for two
# values whose hashes agree in their low 32 bits, which is all a 32-bit
# fold of the line would have kept: the two lines differ only in that
# one option, at the same position, so they would have folded to the
# same name.  With the whole hash in the name they don't.

cat >find.c++ <<'EOT'
#include <cstdint>
#include <cstdio>
#include <string>
#include <unordered_map>
int main(void)
{
    std::hash<std::string> h;
    std::unordered_map<uint32_t, long> seen;
    /* A pair turns up within a few hundred thousand; the bound is
     * only so a broken std::hash ends the test instead of hanging it. */
    for (long i = 0; i < 10000000; ++i) {
        auto key = static_cast<uint32_t>(h("-DVALUE=" + std::to_string(i)));
        auto found = seen.find(key);
        if (found != seen.end()) {
            printf("%ld %ld\n", found->second, i);
            return 0;
        }
        seen[key] = i;
    }
    return 1;
}
EOT
${CXX:-c++} -O2 -o find find.c++
read first second < <(./find)
test -n "$second"

mkdir -p src
cat >src/main.c <<'EOT'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOT

cat >Configfile <<EOT
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -DVALUE=$first
SOURCES     += main.c
EOT
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "$first"

sed -i "s/-DVALUE=$first/-DVALUE=$second/" Configfile
cat Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "$second"

exit 0
