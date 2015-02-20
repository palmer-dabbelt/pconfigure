#include "tempdir.bash"

cat >in.bash <<EOF
FROM
EOF

cat >gold.bash <<EOF
#!/bin/bash

TO
EOF

ARGS="-DFROM=TO"

#include "harness2.bash"
