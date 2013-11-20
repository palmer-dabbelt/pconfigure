set -e

sources=""
jars="."
jarpath="/usr/lib $HOME/.local/lib"
while [[ "$1" != "" ]]
do
    if [[ "$1" == "-o" ]]
    then
	outfile="$2"
	shift
	shift
    elif [[ "$1" == -l* ]]
    then
        lib="$(echo "$1" | sed s/^-l//)"
        if [[ "$1" == "-l" ]]
        then
            lib="$2"
            shift
        fi

	jar="$(find -H $jarpath -name lib"$lib".jar | head -n1)"
	jars="$jar:$jars"
	shift
    elif [[ "$1" == -L* ]]
    then
        lib="$(echo "$1" | sed s/^-L//)"
        if [[ "$1" == "-L" ]]
        then
            lib="$2"
            shift
        fi

	jarpath="$jarpath $lib"
	shift
    else
	sources="$1 $sources"
	shift
    fi
done
workfile="$(basename "$infile")"

if [[ "$(echo $jars)" != "" ]]
then
    classpath="-classpath $jars"
fi

# Make a temporary working directory
#workdir=`mktemp -d -t pscalac.XXXXXX`
#trap "set +e; rm -rf $workdir; rm -f $outfile" EXIT
workdir="$(pwd)"/"$(dirname "$outfile")"/pscalac-cache
mkdir -p "$workdir"

workjar="$workdir"/out.jar

# Copy the Scala file into the current working directory.  We need to
# make sure it's at the correct path, as otherwise I think it won't
# get loaded correctly.
if which zinc >& /dev/null
then
    #strace -f -o "$workdir"/strace -e stat \
	zinc -nailed -q -analysis-cache "$workdir"/zinc.cache \
	$sources -d "$workdir" $classpath || \
        zinc -analysis-cache "$workdir"/zinc.cache \
	$sources -d "$workdir" $classpath

   cd "$workdir"
   find . -iname "*.class" > "$workdir"/jar-list
   cd - >& /dev/null
else
    #strace -f -o "$workdir"/strace -e stat \
	scalac -make:changed $sources -d "$workdir" $classpath

   cd "$workdir"
   find . -iname "*.class" > "$workdir"/jar-list
   cd - >& /dev/null
fi

# There isn't a real way to get a list of clas files that Scala
# outputs, so I guess at it using strace... :)
cd "$workdir"

if test -f "$workdir"/strace
then
    cat "$workdir"/strace | cut -d' ' -f 2- | sed 's/^ //g' \
        | grep "^stat" | sed 's@stat("\(.*\)",.*@\1@' \
        | grep "^$workdir" \
        | (while read f; do test ! -f $f || echo $f; done; ) \
        | sed "s@$workdir/*@@" | grep ".class$" \
        | sort | uniq > "$workdir"/jar-list
fi

cat "$workdir"/jar-list | xargs jar cf "$workjar"

cd - >& /dev/null

# Finally, copy the file
cp "$workjar" "$outfile"

# Clean up
#rm -rf "$workdir"
#trap "true" EXIT
