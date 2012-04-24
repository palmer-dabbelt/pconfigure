# Parses some special command-line options
optional="false"
have=""
while true
do
    if [[ "$1" == "--optional" ]]
    then
	optional="true"
    elif [[ "$1" == "--have" ]]
    then
	shift
	have="$1"
    else
	break
    fi
    
    shift
done

# Actually runs pkg-config
stdout=$(pkg-config $@ 2> /dev/null)
retval="$?"

# If --optional is given then don't panic
if [[ "$retval" != "0" ]]
then
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
    stdout="$stdout -DHAVE_$have"
fi

# Outputs the results of pkg-config
echo $stdout
exit 0
