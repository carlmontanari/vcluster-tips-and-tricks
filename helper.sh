# a simple function to run a command (and optionally show a different command) until some pattern
# is seen or not seen any longer.
doUntil() {
	showCommand=$1
	realCommand=$2
	untilPattern=$3
	negate=$4

	while :; do
	    exec 5>&1
	    p "$showCommand"
	    output=$(eval $realCommand | tee /dev/fd/5)

	    if [ -z "$negate" ]
	    then
		    if grep -E -q $untilPattern <<< "$output"
		    then
		        break
		    fi
		else
			if ! grep -E -q $untilPattern <<< "$output"
		    then
		        break
		    fi
		fi
	done
}