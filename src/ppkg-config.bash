# Parses some special command-line options
optional="false"
pkgconfig="false"
pkgtarget=""
lastarg=""
have=""
args=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--optional" ]]
    then
	optional="true"
    elif [[ "$1" == "--pkgconfig" ]]
    then
        pkgconfig="true"
        pkgtarget="$lastarg"
        args="$args --exists"
    elif [[ "$1" == "--have" ]]
    then
	shift
	have="$1"
    else
	args="$args $1"
        lastarg="$1"
    fi
    
    shift
done

# Actually runs pkg-config
stdout=$(pkg-config $args 2> /dev/null)
retval="$?"

# If --optional is given then don't panic
if [[ "$retval" != "0" ]]
then
    if [[ "$pkgconfig" == "true" && "$have" != "" ]]
    then
        echo "s/@@HAVE_$have@@//g"
    fi

    if [[ "$optional" == "true" ]]
    then
	exit 0
    else
	exit $retval
    fi
fi

# Checks for some special options
if [[ "$have" != "" ]]
then
    if [[ "$pkgconfig" == "true" ]]
    then
        stdout="$stdout s/@@HAVE_$have@@/$pkgtarget/g"
    else
        stdout="$stdout -DHAVE_$have"
    fi
fi

# Outputs the results of pkg-config
echo $stdout
exit 0
