ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`

tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR

CDIR=`pwd`
cd $TMPDIR/work
$PTEST_BINARY

cd $TMPDIR
out="$(diff -ur *)"

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" == "" ]]
then
    exit 0
else
    exit 1
fi

__ARCHIVE_BELOW__
H4sIAD1RkVEAA+3UzYrCMBAH8Jx9itnTXhZMxkz7Cj6AL1DX+IGVSD/w5rObFLZbEPGwprr4/10C
mUIG/p3Z+HI1VWnpIBeJp8lFD88fyrCxlkXrLNwbMzO5IkncV6etm6IiUseiPLjq9nf36v/UJubf
uLpJ+EYMOLP2dv4Z/+YvWcifma0inbCn3pvnP3eV+6ypoPgP0HpXusliG+6o3vq2XNHShdqy+N63
xy9qvP+YPLtjeKSTr/Yvtf8td/tfLPb/GLr8X2n/d/kzC/b/KLD/31s//+d0b9ydfx7M/0zi/NtQ
xvyP4Hr+n90RAAAAAAAAAAAAAAAA/MUFHpQH2AAoAAA=
